// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.
#include "media_kit_video_plugin.h"
#include "utils.h"

#include <Windows.h>

namespace media_kit_video {

MediaKitVideoPlugin* MediaKitVideoPlugin::instance_ = nullptr;

void MediaKitVideoPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<MediaKitVideoPlugin>(registrar);
  registrar->AddPlugin(std::move(plugin));
}

MediaKitVideoPlugin::MediaKitVideoPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar),
      video_output_manager_(std::make_unique<VideoOutputManager>(registrar)) {
  instance_ = this;
  flutter_window_ =
      ::GetAncestor(registrar->GetView()->GetNativeWindow(), GA_ROOT);
  original_window_proc_ = reinterpret_cast<WNDPROC>(
      ::SetWindowLongPtr(flutter_window_, GWLP_WNDPROC,
                         reinterpret_cast<LONG_PTR>(WindowProcDelegate)));

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "com.alexmercerind/media_kit_video",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([&](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
}

MediaKitVideoPlugin::~MediaKitVideoPlugin() {
  if (flutter_window_ && original_window_proc_) {
    ::SetWindowLongPtr(flutter_window_, GWLP_WNDPROC,
                       reinterpret_cast<LONG_PTR>(original_window_proc_));
  }
  if (instance_ == this) {
    instance_ = nullptr;
  }
}

void MediaKitVideoPlugin::RunOnMainThread(std::function<void()> task) {
  if (!flutter_window_) {
    return;
  }

  {
    std::lock_guard<std::mutex> lock(main_thread_tasks_mutex_);
    main_thread_tasks_.push(std::move(task));
  }

  ::PostMessage(flutter_window_, kMainThreadTaskMessage, 0, 0);
}

LRESULT CALLBACK MediaKitVideoPlugin::WindowProcDelegate(HWND hwnd,
                                                         UINT message,
                                                         WPARAM wParam,
                                                         LPARAM lParam) {
  if (message == kMainThreadTaskMessage && instance_) {
    instance_->ProcessMainThreadTasks();
    return 0;
  }

  if (instance_ && instance_->original_window_proc_) {
    return ::CallWindowProc(instance_->original_window_proc_, hwnd, message,
                            wParam, lParam);
  }

  return ::DefWindowProc(hwnd, message, wParam, lParam);
}

void MediaKitVideoPlugin::ProcessMainThreadTasks() {
  std::queue<std::function<void()>> tasks_to_execute;

  {
    std::lock_guard<std::mutex> lock(main_thread_tasks_mutex_);
    tasks_to_execute.swap(main_thread_tasks_);
  }

  while (!tasks_to_execute.empty()) {
    auto task = std::move(tasks_to_execute.front());
    tasks_to_execute.pop();

    try {
      task();
    } catch (...) {
    }
  }
}

void MediaKitVideoPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("Utils.GetD3D11Adapters") == 0) {
    flutter::EncodableList adapters;
    for (const auto& adapter : Utils::GetD3D11Adapters()) {
      adapters.emplace_back(flutter::EncodableMap{
          {flutter::EncodableValue("id"), flutter::EncodableValue(adapter.id)},
          {flutter::EncodableValue("name"),
           flutter::EncodableValue(adapter.name)},
          {flutter::EncodableValue("dedicatedVideoMemoryMb"),
           flutter::EncodableValue(adapter.dedicated_video_memory_mb)},
      });
    }
    result->Success(flutter::EncodableValue(std::move(adapters)));
  } else if (method_call.method_name().compare("VideoOutputManager.Create") ==
             0) {
    auto arguments = std::get<flutter::EncodableMap>(*method_call.arguments());
    const auto library = arguments.find(flutter::EncodableValue("libmpv"));
    if (library == arguments.end() ||
        !std::holds_alternative<std::string>(library->second) ||
        media_kit_mpv_initialize(std::get<std::string>(library->second).c_str()) != 0) {
      result->Error("libmpv", "Could not bind the player's libmpv library.");
      return;
    }
    auto handle =
        std::get<std::string>(arguments[flutter::EncodableValue("handle")]);
    auto configuration = std::get<flutter::EncodableMap>(
        arguments[flutter::EncodableValue("configuration")]);

    auto handle_value = std::stoll(handle);
    auto configuration_value = VideoOutputConfiguration{};

    auto configuration_width =
        std::get<std::string>(configuration[flutter::EncodableValue("width")]);
    auto configuration_height =
        std::get<std::string>(configuration[flutter::EncodableValue("height")]);
    auto configuration_enable_hardware_acceleration = std::get<bool>(
        configuration[flutter::EncodableValue("enableHardwareAcceleration")]);
    auto configuration_adapter = std::string("auto");
    const auto adapter_setting =
        configuration.find(flutter::EncodableValue("windowsD3D11Adapter"));
    if (adapter_setting != configuration.end() &&
        std::holds_alternative<std::string>(adapter_setting->second)) {
      configuration_adapter = std::get<std::string>(adapter_setting->second);
    }
    if (configuration_width.compare("null") != 0) {
      configuration_value.width =
          static_cast<int64_t>(std::stoll(configuration_width.c_str()));
    }
    if (configuration_height.compare("null") != 0) {
      configuration_value.height =
          static_cast<int64_t>(std::stoll(configuration_height.c_str()));
    }
    configuration_value.enable_hardware_acceleration =
        configuration_enable_hardware_acceleration;
    configuration_value.windows_d3d11_adapter = configuration_adapter;

    video_output_manager_->Create(
        handle_value, configuration_value,
        [this, handle = handle_value](auto id, auto width, auto height) {
          RunOnMainThread([=]() {
            channel_->InvokeMethod(
                "VideoOutput.Resize",
                std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
                    {
                        flutter::EncodableValue("handle"),
                        flutter::EncodableValue(handle),
                    },
                    {
                        flutter::EncodableValue("id"),
                        flutter::EncodableValue(id),
                    },
                    {
                        flutter::EncodableValue("rect"),
                        flutter::EncodableValue(flutter::EncodableMap{
                            {
                                flutter::EncodableValue("left"),
                                flutter::EncodableValue(0),
                            },
                            {
                                flutter::EncodableValue("top"),
                                flutter::EncodableValue(0),
                            },
                            {
                                flutter::EncodableValue("width"),
                                flutter::EncodableValue(width),
                            },
                            {
                                flutter::EncodableValue("height"),
                                flutter::EncodableValue(height),
                            },
                        }),
                    },
                }),
                nullptr);
          });
        },
        [this, handle = handle_value](std::string message) {
          RunOnMainThread([this, handle, message = std::move(message)]() {
            channel_->InvokeMethod(
                "VideoOutput.Error",
                std::make_unique<flutter::EncodableValue>(
                    flutter::EncodableMap{
                        {flutter::EncodableValue("handle"),
                         flutter::EncodableValue(handle)},
                        {flutter::EncodableValue("message"),
                         flutter::EncodableValue(message)},
                    }),
                nullptr);
          });
        });
    result->Success(flutter::EncodableValue(std::monostate{}));
  } else if (method_call.method_name().compare("VideoOutputManager.Dispose") ==
             0) {
    auto arguments = std::get<flutter::EncodableMap>(*method_call.arguments());
    auto handle =
        std::get<std::string>(arguments[flutter::EncodableValue("handle")]);
    auto handle_value = static_cast<int64_t>(std::stoll(handle.c_str()));
    auto completion =
        std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
    video_output_manager_->Dispose(handle_value, [this, completion]() {
      RunOnMainThread([completion]() {
        completion->Success(flutter::EncodableValue(std::monostate{}));
      });
    });
  } else if (method_call.method_name().compare("VideoOutputManager.SetSize") ==
             0) {
    auto arguments = std::get<flutter::EncodableMap>(*method_call.arguments());
    auto handle =
        std::get<std::string>(arguments[flutter::EncodableValue("handle")]);
    auto width =
        std::get<std::string>(arguments[flutter::EncodableValue("width")]);
    auto height =
        std::get<std::string>(arguments[flutter::EncodableValue("height")]);
    auto handle_value = static_cast<int64_t>(std::stoll(handle.c_str()));
    auto width_value = std::optional<int64_t>{};
    auto height_value = std::optional<int64_t>{};
    if (width.compare("null") != 0) {
      width_value = static_cast<int64_t>(std::stoll(width.c_str()));
    }
    if (height.compare("null") != 0) {
      height_value = static_cast<int64_t>(std::stoll(height.c_str()));
    }
    video_output_manager_->SetSize(handle_value, width_value, height_value);
    result->Success(flutter::EncodableValue(std::monostate{}));
  } else if (method_call.method_name().compare("Utils.EnterNativeFullscreen") ==
             0) {
    auto window =
        ::GetAncestor(registrar_->GetView()->GetNativeWindow(), GA_ROOT);
    Utils::EnterNativeFullscreen(window);
    result->Success(flutter::EncodableValue(std::monostate{}));
  } else if (method_call.method_name().compare("Utils.ExitNativeFullscreen") ==
             0) {
    auto window =
        ::GetAncestor(registrar_->GetView()->GetNativeWindow(), GA_ROOT);
    Utils::ExitNativeFullscreen(window);
    result->Success(flutter::EncodableValue(std::monostate{}));
  } else {
    result->NotImplemented();
  }
}

}  // namespace media_kit_video
