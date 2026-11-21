// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "video_output.h"
#include "video_adapters.h"
#include "../common/video_dimensions.h"

#include <algorithm>
#include <utility>
#include <vector>

// Software rendering stays within 1080p, preserving the source aspect ratio.
constexpr int64_t kSoftwareMaxWidth = 1920;
constexpr int64_t kSoftwareMaxHeight = 1080;

struct VideoOutput::PixelFrame {
  std::vector<uint8_t> pixels;
  size_t width = 0;
  size_t height = 0;
};

VideoOutput::VideoOutput(int64_t handle,
                         VideoOutputConfiguration configuration,
                         flutter::PluginRegistrarWindows* registrar,
                         ThreadPool* thread_pool_ref,
                         std::function<void(std::string)> report_warning)
    : handle_(reinterpret_cast<mpv_handle*>(handle)),
      width_(configuration.width),
      height_(configuration.height),
      configuration_(configuration),
      registrar_(registrar),
      thread_pool_ref_(thread_pool_ref),
      report_warning_(std::move(report_warning)) {
  // The constructor must be invoked through the thread pool.
  auto future = thread_pool_ref_->Post([&]() {
    mpv_set_option_string(handle_, "video-sync", "audio");
    mpv_set_option_string(handle_, "video-timing-offset", "0");

    bool is_hardware_acceleration_enabled = false;
    if (configuration_.enable_hardware_acceleration) {
      IDXGIAdapter* flutter_adapter = nullptr;
      if (auto* view = registrar_->GetView()) {
        flutter_adapter = view->GetGraphicsAdapter();
      }
      auto create_renderer = [&](IDXGIAdapter* adapter) {
        try {
          d3d11_renderer_ = std::make_unique<D3D11Renderer>(
              static_cast<int32_t>(width_.value_or(1)),
              static_cast<int32_t>(height_.value_or(1)), flutter_adapter, adapter);
          mpv_d3d11_init_params init_params = {d3d11_renderer_->device()};
          mpv_render_param params[] = {
              {MPV_RENDER_PARAM_API_TYPE, MPV_RENDER_API_TYPE_D3D11},
              {MPV_RENDER_PARAM_D3D11_INIT_PARAMS, &init_params},
              {MPV_RENDER_PARAM_INVALID, nullptr},
          };
          const int status =
              mpv_render_context_create(&render_context_, handle_, params);
          if (status >= 0) {
            RegisterTexture();
            mpv_render_context_set_update_callback(
                render_context_, [](void* context) {
                  static_cast<VideoOutput*>(context)->NotifyRender();
                }, this);
            return true;
          }
          std::cout << "media_kit: MPV D3D11 init failed: " << status << '\n';
        } catch (const std::exception& error) {
          std::cout << "media_kit: D3D11 init failed: " << error.what() << '\n';
        }
        if (render_context_) {
          mpv_render_context_free(render_context_);
          render_context_ = nullptr;
        }
        d3d11_renderer_.reset();
        return false;
      };

      if (!configuration_.render_adapter_id.empty()) {
        const auto selected = FindVideoAdapter(configuration_.render_adapter_id);
        is_hardware_acceleration_enabled = selected && create_renderer(selected.Get());
        if (!is_hardware_acceleration_enabled) report_warning_("adapterFallback");
      }
      if (!is_hardware_acceleration_enabled) {
        is_hardware_acceleration_enabled = create_renderer(nullptr);
      }
      if (!is_hardware_acceleration_enabled) report_warning_("softwareFallback");
    }

    if (!is_hardware_acceleration_enabled) {

      mpv_render_param params[] = {
          {MPV_RENDER_PARAM_API_TYPE, MPV_RENDER_API_TYPE_SW},
          {MPV_RENDER_PARAM_INVALID, nullptr},
      };
      if (mpv_render_context_create(&render_context_, handle_, params) == 0) {
        RegisterTexture();
        mpv_render_context_set_update_callback(
            render_context_,
            [](void* context) {
              auto that = reinterpret_cast<VideoOutput*>(context);
              that->NotifyRender();
            },
            reinterpret_cast<void*>(this));
      }
    }
  });
  future.wait();
}

VideoOutput::~VideoOutput() {
  destroyed_ = true;
  if (render_context_) {
    // Stop the producer before draining queued tasks that borrow this object.
    mpv_render_context_set_update_callback(render_context_, nullptr, nullptr);
  }
  thread_pool_ref_->Post([this]() {
    if (render_context_) mpv_render_context_free(render_context_);
    d3d11_renderer_.reset();
  }).wait();
  if (texture_id_) {
    // The engine can release this on the raster thread after VideoOutput dies.
    // All attributes reachable from the callback have their own lifetime.
    registrar_->texture_registrar()->UnregisterTexture(
        texture_id_, [texture = std::move(texture_)]() {});
  }
}

void VideoOutput::NotifyRender() {
  if (destroyed_ || render_queued_.exchange(true)) return;
  thread_pool_ref_->Post([this]() {
    render_queued_ = false;
    CheckAndResize();
    Render();
  });
}

void VideoOutput::Render() {
  if (!destroyed_ && render_context_ && texture_id_) {
    // H/W
    if (d3d11_renderer_ != nullptr) {
      // mpv renders into the mailbox slot owned by the producer and flushes
      // its work to the immediate context before returning.
      mpv_d3d11_fbo fbo = {d3d11_renderer_->render_target()};
      mpv_render_param params[]{
          {MPV_RENDER_PARAM_D3D11_FBO, &fbo},
          {MPV_RENDER_PARAM_INVALID, nullptr},
      };
      // Publish the slot only if mpv actually rendered into it.
      if (mpv_render_context_render(render_context_, params) < 0 ||
          !d3d11_renderer_->ProducerCommit()) {
        if (!transfer_warning_reported_) {
          transfer_warning_reported_ = true;
          report_warning_("renderFailed");
        }
        return;
      }

      std::atomic_store(gpu_surface_.get(), d3d11_renderer_->mailbox());
      PublishSize(d3d11_renderer_->width(), d3d11_renderer_->height());
    } else {
      auto slot = std::find_if(pixel_slots_.begin(), pixel_slots_.end(),
                              [](const auto& frame) { return !frame || frame.use_count() == 1; });
      if (slot == pixel_slots_.end()) return;
      if (!*slot) *slot = std::make_shared<PixelFrame>();
      auto& frame = **slot;
      int size[] = {requested_width_, requested_height_};
      size_t pitch = static_cast<size_t>(size[0]) * 4;
      frame.width = size[0];
      frame.height = size[1];
      frame.pixels.resize(pitch * frame.height);
      mpv_render_param params[] = {
          {MPV_RENDER_PARAM_SW_SIZE, size},
          {MPV_RENDER_PARAM_SW_FORMAT, const_cast<char*>("rgb0")},
          {MPV_RENDER_PARAM_SW_STRIDE, &pitch},
          {MPV_RENDER_PARAM_SW_POINTER, frame.pixels.data()},
          {MPV_RENDER_PARAM_INVALID, nullptr},
      };
      if (mpv_render_context_render(render_context_, params) < 0) return;
      // rgb0 does not define its fourth byte. Flutter imports RGBA, so make
      // the actual frame opaque before publishing it to the compositor.
      for (size_t i = 3; i < frame.pixels.size(); i += 4) frame.pixels[i] = 255;
      std::atomic_store(pixel_surface_.get(), *slot);
      PublishSize(size[0], size[1]);
    }
    try {
      // Notify Flutter that a new frame is available.
      registrar_->texture_registrar()->MarkTextureFrameAvailable(texture_id_);
    } catch (...) {
      // Prevent any redundant exceptions if the texture is unregistered etc.
    }
  }
}

void VideoOutput::SetTextureUpdateCallback(
    std::function<void(int64_t, int64_t, int64_t)> callback) {
  thread_pool_ref_->Post([this, callback = std::move(callback)]() {
    texture_update_callback_ = callback;
    texture_update_callback_(texture_id_, published_width_, published_height_);
  }).wait();
}

void VideoOutput::SetSize(std::optional<int64_t> width,
                          std::optional<int64_t> height) {
  thread_pool_ref_->Post([this, width, height]() {
    if (destroyed_) return;
    width_ = width;
    height_ = height;
    CheckAndResize();
    Render();
  });
}

void VideoOutput::CheckAndResize() {
  if (destroyed_ || !texture_id_) return;
  const auto [width, height] = RequestedSize();
  if (width == requested_width_ && height == requested_height_) return;
  if (d3d11_renderer_) {
    const std::pair<int64_t, int64_t> size{width, height};
    if (failed_size_ == size) return;
    if (!d3d11_renderer_->SetSize(width, height)) {
      failed_size_ = size;
      report_warning_("resizeFailed");
      return;
    }
    failed_size_.reset();
  }
  requested_width_ = width;
  requested_height_ = height;
}

void VideoOutput::PublishSize(int width, int height) {
  if (width == published_width_ && height == published_height_) return;
  published_width_ = width;
  published_height_ = height;
  texture_update_callback_(texture_id_, width, height);
}

void VideoOutput::RegisterTexture() {
  if (d3d11_renderer_) {
    struct D3DConsumer {
      std::shared_ptr<MailboxSwapChain> bound;
      std::shared_ptr<MailboxSwapChain> prior;
      FlutterDesktopGpuSurfaceDescriptor descriptor{};
    };
    gpu_surface_ = std::make_shared<std::shared_ptr<MailboxSwapChain>>();
    texture_ = std::make_shared<flutter::TextureVariant>(flutter::GpuSurfaceTexture(
        kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle,
        [source = gpu_surface_, consumer = std::make_shared<D3DConsumer>()](auto, auto)
            -> const FlutterDesktopGpuSurfaceDescriptor* {
          auto mailbox = std::atomic_load(source.get());
          if (!mailbox) return nullptr;
          const auto handle = mailbox->ConsumerAcquire();
          if (!handle) return nullptr;
          if (consumer->bound != mailbox) {
            consumer->prior = std::exchange(consumer->bound, std::move(mailbox));
          }
          auto& desc = consumer->descriptor;
          desc.struct_size = sizeof(desc);
          desc.handle = handle;
          desc.width = desc.visible_width = consumer->bound->width();
          desc.height = desc.visible_height = consumer->bound->height();
          desc.format = kFlutterDesktopPixelFormatBGRA8888;
          desc.release_context = consumer.get();
          desc.release_callback = [](void* ptr) {
            auto& surface = *static_cast<D3DConsumer*>(ptr);
            surface.bound->ConsumerReleasePrevious();
            surface.prior.reset();
          };
          // Flutter reads descriptor dimensions after the release callback.
          // Free the previous resource, not the descriptor, in that callback.
          return &desc;
        }));
  } else {
    struct PixelConsumer {
      std::shared_ptr<PixelFrame> frame;
      FlutterDesktopPixelBuffer descriptor{};
    };
    pixel_surface_ = std::make_shared<std::shared_ptr<PixelFrame>>();
    texture_ = std::make_shared<flutter::TextureVariant>(flutter::PixelBufferTexture(
        [source = pixel_surface_, consumer = std::make_shared<PixelConsumer>()](auto, auto)
            -> const FlutterDesktopPixelBuffer* {
          consumer->frame = std::atomic_load(source.get());
          if (!consumer->frame) return nullptr;
          const auto& frame = *consumer->frame;
          consumer->descriptor = {
              frame.pixels.data(), frame.width, frame.height,
              [](void* ptr) { static_cast<PixelConsumer*>(ptr)->frame.reset(); },
              consumer.get(),
          };
          return &consumer->descriptor;
        }));
  }
  texture_id_ = registrar_->texture_registrar()->RegisterTexture(texture_.get());
}

std::pair<int, int> VideoOutput::RequestedSize() {
  const auto [native_width, native_height] = media_kit::GetVideoDimensions(handle_);
  auto width = width_.value_or(native_width);
  auto height = height_.value_or(native_height);
  if (width <= 0 || height <= 0) return {requested_width_, requested_height_};
  if (!d3d11_renderer_) {
    const auto scale = (std::min)({1., static_cast<double>(kSoftwareMaxWidth) / width,
                                static_cast<double>(kSoftwareMaxHeight) / height});
    width = std::max<int64_t>(1, static_cast<int64_t>(width * scale));
    height = std::max<int64_t>(1, static_cast<int64_t>(height * scale));
  }
  return {static_cast<int>(width), static_cast<int>(height)};
}
