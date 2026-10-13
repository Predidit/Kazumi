// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2025 & onwards, Predidit.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef GL_RENDER_THREAD_H_
#define GL_RENDER_THREAD_H_

#include <glib.h>
#include <functional>
#include <thread>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <atomic>

class GLRenderThread {
 public:
  GLRenderThread();
  ~GLRenderThread();

  // Post a task to the GL render thread
  void Post(std::function<void()> task);

  // Post a task and wait for completion (synchronous)
  void PostAndWait(std::function<void()> task);

 private:
  void Run();

  std::thread thread_;
  std::thread::id thread_id_;
  std::queue<std::function<void()>> tasks_;
  std::mutex mutex_;
  std::condition_variable cv_;
  std::atomic<bool> stop_;
};

#endif  // GL_RENDER_THREAD_H_
