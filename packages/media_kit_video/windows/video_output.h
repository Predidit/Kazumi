// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef VIDEO_OUTPUT_H_
#define VIDEO_OUTPUT_H_

#include <array>
#include <atomic>
#include <optional>

#include "media_kit_mpv.h"
#include "mpv/render_d3d11.h"

#include <future>
#include <memory>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include "d3d11_renderer.h"
#include "thread_pool.h"

typedef struct _VideoOutputConfiguration {
  std::optional<int64_t> width;
  std::optional<int64_t> height;
  bool enable_hardware_acceleration;
  std::string render_adapter_id;

  _VideoOutputConfiguration(std::optional<int64_t> width = std::nullopt,
                            std::optional<int64_t> height = std::nullopt,
                            bool enable_hardware_acceleration = true)
      : width(width),
        height(height),
        enable_hardware_acceleration(enable_hardware_acceleration) {}
} VideoOutputConfiguration;

class VideoOutput {
 public:
  VideoOutput(int64_t handle,
              VideoOutputConfiguration configuration,
              flutter::PluginRegistrarWindows* registrar,
              ThreadPool* thread_pool_ref,
              std::function<void(std::string)> report_warning);

  ~VideoOutput();

  void SetTextureUpdateCallback(
      std::function<void(int64_t, int64_t, int64_t)> callback);

  void SetSize(std::optional<int64_t> width, std::optional<int64_t> height);

 private:
  void NotifyRender();

  void Render();

  void CheckAndResize();

  void RegisterTexture();
  void PublishSize(int width, int height);
  std::pair<int, int> RequestedSize();

  std::optional<int64_t> height_ = std::nullopt;
  std::optional<int64_t> width_ = std::nullopt;
  VideoOutputConfiguration configuration_ = VideoOutputConfiguration{};

  mpv_handle* handle_ = nullptr;
  mpv_render_context* render_context_ = nullptr;
  int64_t texture_id_ = 0;
  flutter::PluginRegistrarWindows* registrar_ = nullptr;
  ThreadPool* thread_pool_ref_ = nullptr;
  // Stop queued callbacks before draining and freeing their borrowed resources.
  std::atomic<bool> destroyed_{false};

  std::unique_ptr<D3D11Renderer> d3d11_renderer_;
  std::shared_ptr<flutter::TextureVariant> texture_;
  // Register exactly once. Keep the last completed frame visible while a
  // replacement is rendered, including through fullscreen/window resize.
  std::shared_ptr<std::shared_ptr<MailboxSwapChain>> gpu_surface_;
  struct PixelFrame;
  std::array<std::shared_ptr<PixelFrame>, 3> pixel_slots_;
  std::shared_ptr<std::shared_ptr<PixelFrame>> pixel_surface_;
  int requested_width_ = 1;
  int requested_height_ = 1;
  int published_width_ = 1;
  int published_height_ = 1;
  std::atomic<bool> render_queued_{false};

  std::function<void(std::string)> report_warning_;
  bool transfer_warning_reported_ = false;
  std::optional<std::pair<int64_t, int64_t>> failed_size_;

  // Public notifier. This is called when a new texture is registered & texture
  // ID is changed. Only happens when video output resolution changes.
  std::function<void(int64_t, int64_t, int64_t)> texture_update_callback_ =
      [](int64_t, int64_t, int64_t) {};
};

#endif  // VIDEO_OUTPUT_H_
