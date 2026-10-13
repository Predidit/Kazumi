// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef VIDEO_OUTPUT_MANAGER_H_
#define VIDEO_OUTPUT_MANAGER_H_

#include <flutter/plugin_registrar_windows.h>

#include <unordered_map>

#include "thread_pool.h"
#include "video_output.h"

class VideoOutputManager {
 public:
  VideoOutputManager(flutter::PluginRegistrarWindows* registrar);

  void Create(
      int64_t handle,
      VideoOutputConfiguration configuration,
      std::function<void(int64_t, int64_t, int64_t)> texture_update_callback,
      std::function<void(std::string)> error_callback);

  void SetSize(int64_t handle,
               std::optional<int64_t> width,
               std::optional<int64_t> height);

  // Completion follows render-context destruction.
  void Dispose(int64_t handle, std::function<void()> on_disposed);

  ~VideoOutputManager();

 private:
  std::mutex mutex_ = std::mutex();
  // D3D11 and mpv rendering share one worker; destruction drains its queue.
  std::unique_ptr<ThreadPool> thread_pool_ = std::make_unique<ThreadPool>(1);
  flutter::PluginRegistrarWindows* registrar_ = nullptr;
  std::unordered_map<int64_t, std::unique_ptr<VideoOutput>> video_outputs_ = {};
};

#endif  // VIDEO_OUTPUT_MANAGER_H_
