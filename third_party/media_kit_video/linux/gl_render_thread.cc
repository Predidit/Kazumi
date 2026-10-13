// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2025 & onwards, Predidit.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/gl_render_thread.h"
#include <pthread.h>
#include <sched.h>

GLRenderThread::GLRenderThread() : stop_(false) {
  // Start the dedicated GL render thread
  thread_ = std::thread([this]() { Run(); });

  // Set thread priority to realtime for smooth rendering
  pthread_t thread_handle = thread_.native_handle();
  struct sched_param params;
  params.sched_priority = sched_get_priority_max(SCHED_FIFO);
  pthread_setschedparam(thread_handle, SCHED_FIFO, &params);

  // Wait for thread to start and capture its ID
  std::unique_lock<std::mutex> lock(mutex_);
  cv_.wait(lock, [this]() { return thread_id_ != std::thread::id(); });
}

GLRenderThread::~GLRenderThread() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    stop_ = true;
  }
  cv_.notify_one();

  if (thread_.joinable()) {
    thread_.join();
  }
}

void GLRenderThread::Post(std::function<void()> task) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (stop_) {
      return;
    }
    tasks_.push(std::move(task));
  }
  cv_.notify_one();
}

void GLRenderThread::PostAndWait(std::function<void()> task) {
  std::mutex wait_mutex;
  std::condition_variable wait_cv;
  bool done = false;

  Post([&]() {
    task();
    {
      std::lock_guard<std::mutex> lock(wait_mutex);
      done = true;
    }
    wait_cv.notify_one();
  });

  std::unique_lock<std::mutex> lock(wait_mutex);
  wait_cv.wait(lock, [&]() { return done; });
}

void GLRenderThread::Run() {
  // Store thread ID
  {
    std::lock_guard<std::mutex> lock(mutex_);
    thread_id_ = std::this_thread::get_id();
  }
  cv_.notify_one();

  // Main loop: process tasks
  while (true) {
    std::function<void()> task;

    {
      std::unique_lock<std::mutex> lock(mutex_);
      cv_.wait(lock, [this]() { return stop_ || !tasks_.empty(); });

      if (stop_ && tasks_.empty()) {
        break;
      }

      if (!tasks_.empty()) {
        task = std::move(tasks_.front());
        tasks_.pop();
      }
    }

    if (task) {
      task();
    }
  }
}
