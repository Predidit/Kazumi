// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "video_output_manager.h"

VideoOutputManager::VideoOutputManager(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}

void VideoOutputManager::Create(
    int64_t handle,
    VideoOutputConfiguration configuration,
    std::function<void(int64_t, int64_t, int64_t)> texture_update_callback,
    std::function<void(std::string)> error_callback) {
  std::thread([=]() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (video_outputs_.find(handle) == video_outputs_.end()) {
      auto instance = std::make_unique<VideoOutput>(
          handle, configuration, registrar_, thread_pool_.get(),
          std::move(error_callback));
      instance->SetTextureUpdateCallback(texture_update_callback);
      video_outputs_.insert(std::make_pair(handle, std::move(instance)));
    }
  }).detach();
}

void VideoOutputManager::SetSize(int64_t handle,
                                std::optional<int64_t> width,
                                std::optional<int64_t> height) {
  std::thread([=]() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (video_outputs_.find(handle) != video_outputs_.end()) {
      video_outputs_[handle]->SetSize(width, height);
    }
  }).detach();
}

void VideoOutputManager::Dispose(int64_t handle,
                                std::function<void()> on_disposed) {
  std::thread([=]() {
    std::lock_guard<std::mutex> lock(mutex_);
    video_outputs_.erase(handle);
    on_disposed();
  }).detach();
}

VideoOutputManager::~VideoOutputManager() {
  std::lock_guard<std::mutex> lock(mutex_);
  video_outputs_.clear();
}
