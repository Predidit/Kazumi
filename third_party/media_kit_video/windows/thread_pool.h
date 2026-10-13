// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.
#ifndef THREAD_POOL_H_
#define THREAD_POOL_H_

#include <functional>
#include <future>
#include <queue>

#ifdef _WIN32
#include <Windows.h>
#endif

class ThreadPool {
 public:
  explicit ThreadPool(size_t);
  template <class F, class... Args>
  decltype(auto) Post(F&& f, Args&&... args);
  ~ThreadPool();

 private:
  std::vector<std::thread> workers_;
  std::queue<std::packaged_task<void()>> tasks_;

  std::mutex queue_mutex_;
  std::condition_variable condition_;
  std::condition_variable condition_producers_;
  bool stop_;
};

inline ThreadPool::ThreadPool(size_t threads) : stop_(false) {
  for (size_t i = 0; i < threads; i++) {
    workers_.emplace_back([&] {
      for (;;) {
        std::packaged_task<void()> task;
        {
          std::unique_lock<std::mutex> lock(queue_mutex_);
          condition_.wait(lock, [&] { return stop_ || !tasks_.empty(); });
          if (stop_ && tasks_.empty())
            return;
          task = std::move(tasks_.front());
          tasks_.pop();
          if (tasks_.empty()) {
            condition_producers_.notify_one();
          }
        }
        task();
      }
    });
#ifdef _WIN32
    ::SetThreadPriority(workers_.back().native_handle(),
                        THREAD_PRIORITY_HIGHEST);
#endif
  }
}

template <class F, class... Args>
decltype(auto) ThreadPool::Post(F&& f, Args&&... args) {
  using return_type = std::invoke_result_t<F, Args...>;
  std::packaged_task<return_type()> task(
      std::bind(std::forward<F>(f), std::forward<Args>(args)...));
  std::future<return_type> res = task.get_future();
  {
    std::unique_lock<std::mutex> lock(queue_mutex_);
    if (stop_) {
      throw std::runtime_error("ThreadPool::Post");
    }
    tasks_.emplace(std::move(task));
  }
  condition_.notify_one();
  return res;
}

inline ThreadPool::~ThreadPool() {
  {
    std::unique_lock<std::mutex> lock(queue_mutex_);
    condition_producers_.wait(lock, [this] { return tasks_.empty(); });
    stop_ = true;
  }
  condition_.notify_all();
  for (std::thread& worker : workers_) {
    worker.join();
  }
}

#endif  // THREAD_POOL_H_
