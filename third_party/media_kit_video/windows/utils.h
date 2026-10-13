// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef UTILS_H_
#define UTILS_H_

#include <cstdint>
#include <string>
#include <vector>

#include <Windows.h>
#include <dxgi1_2.h>
#include <wrl.h>

struct D3D11AdapterInfo {
  std::string id;
  std::string name;
  int64_t dedicated_video_memory_mb = 0;
};

class Utils {
 public:
  static void EnterNativeFullscreen(HWND window);

  static void ExitNativeFullscreen(HWND window);

  static RTL_OSVERSIONINFOW GetWindowsVersion();

  static bool IsWindows10RTMOrGreater();

  static std::vector<D3D11AdapterInfo> GetD3D11Adapters();

  static Microsoft::WRL::ComPtr<IDXGIAdapter1> FindD3D11Adapter(
      const std::string& id);

  static std::string D3D11AdapterId(const LUID& luid);

 private:
  static constexpr auto kFlutterViewWindowClassName = L"FLUTTERVIEW";

  static bool fullscreen_;
  static RECT rect_before_fullscreen_;
};

#endif  // UTILS_H_
