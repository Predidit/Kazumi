// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "utils.h"

#include <iomanip>
#include <sstream>
#include <utility>

typedef LONG NTSTATUS, *PNTSTATUS;
#define STATUS_SUCCESS (0x00000000)

typedef NTSTATUS(WINAPI* RtlGetVersionPtr)(PRTL_OSVERSIONINFOW);

std::string Utils::D3D11AdapterId(const LUID& luid) {
  std::ostringstream id;
  id << std::hex << std::setfill('0') << std::setw(8)
     << static_cast<uint32_t>(luid.HighPart) << ':' << std::setw(8)
     << luid.LowPart;
  return id.str();
}

std::vector<D3D11AdapterInfo> Utils::GetD3D11Adapters() {
  std::vector<D3D11AdapterInfo> adapters;
  Microsoft::WRL::ComPtr<IDXGIFactory1> factory;
  if (FAILED(::CreateDXGIFactory1(__uuidof(IDXGIFactory1),
                                 reinterpret_cast<void**>(
                                     factory.GetAddressOf()))) ||
      !factory) {
    return adapters;
  }

  for (UINT index = 0;; ++index) {
    Microsoft::WRL::ComPtr<IDXGIAdapter1> adapter;
    const HRESULT hr = factory->EnumAdapters1(index, adapter.GetAddressOf());
    if (hr == DXGI_ERROR_NOT_FOUND) {
      break;
    }
    if (FAILED(hr)) return adapters;
    if (!adapter) {
      continue;
    }

    DXGI_ADAPTER_DESC1 description = {};
    if (FAILED(adapter->GetDesc1(&description)) ||
        (description.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) != 0) {
      continue;
    }

    const int name_length = ::WideCharToMultiByte(
        CP_UTF8, 0, description.Description, -1, nullptr, 0, nullptr, nullptr);
    if (name_length <= 1) {
      continue;
    }
    std::string name(static_cast<size_t>(name_length), '\0');
    ::WideCharToMultiByte(CP_UTF8, 0, description.Description, -1, name.data(),
                          name_length, nullptr, nullptr);
    name.resize(static_cast<size_t>(name_length - 1));

    adapters.push_back({
        D3D11AdapterId(description.AdapterLuid),
        std::move(name),
        static_cast<int64_t>(description.DedicatedVideoMemory / (1024 * 1024)),
    });
  }

  return adapters;
}

Microsoft::WRL::ComPtr<IDXGIAdapter1> Utils::FindD3D11Adapter(
    const std::string& id) {
  Microsoft::WRL::ComPtr<IDXGIFactory1> factory;
  if (FAILED(::CreateDXGIFactory1(__uuidof(IDXGIFactory1),
                                 reinterpret_cast<void**>(
                                     factory.GetAddressOf()))) ||
      !factory) {
    return {};
  }

  for (UINT index = 0;; ++index) {
    Microsoft::WRL::ComPtr<IDXGIAdapter1> adapter;
    const HRESULT hr = factory->EnumAdapters1(index, adapter.GetAddressOf());
    if (hr == DXGI_ERROR_NOT_FOUND) {
      break;
    }
    if (FAILED(hr)) return {};
    if (!adapter) {
      continue;
    }

    DXGI_ADAPTER_DESC1 description = {};
    if (SUCCEEDED(adapter->GetDesc1(&description)) &&
        D3D11AdapterId(description.AdapterLuid) == id) {
      return adapter;
    }
  }

  return {};
}

void Utils::EnterNativeFullscreen(HWND window) {
  if (fullscreen_) {
    return;
  }
  fullscreen_ = true;

  // The primary idea here is to revolve around |WS_OVERLAPPEDWINDOW| &
  // detect/set fullscreen based on it. In the window procedure, this is
  // separately handled. If there is no |WS_OVERLAPPEDWINDOW| style on the
  // window i.e. in fullscreen, then no area is left for |WM_NCHITTEST|,
  // accordingly client area is also expanded to fill whole monitor using
  // |WM_NCCALCSIZE|.

  auto style = ::GetWindowLongPtr(window, GWL_STYLE);
  if (style & WS_OVERLAPPEDWINDOW) {
    auto monitor = MONITORINFO{};
    auto placement = WINDOWPLACEMENT{};
    monitor.cbSize = sizeof(MONITORINFO);
    placement.length = sizeof(WINDOWPLACEMENT);
    ::GetWindowPlacement(window, &placement);
    rect_before_fullscreen_ = RECT{
        placement.rcNormalPosition.left,
        placement.rcNormalPosition.top,
        placement.rcNormalPosition.right,
        placement.rcNormalPosition.bottom,
    };
    ::GetMonitorInfo(::MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST),
                     &monitor);
    ::SetWindowLongPtr(window, GWL_STYLE, style & ~WS_OVERLAPPEDWINDOW);
    ::SetWindowPos(window, HWND_TOP, monitor.rcMonitor.left,
                   monitor.rcMonitor.top,
                   monitor.rcMonitor.right - monitor.rcMonitor.left,
                   monitor.rcMonitor.bottom - monitor.rcMonitor.top,
                   SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  }
}

void Utils::ExitNativeFullscreen(HWND window) {
  if (!fullscreen_) {
    return;
  }
  fullscreen_ = false;

  auto style = ::GetWindowLongPtr(window, GWL_STYLE);
  if (!(style & WS_OVERLAPPEDWINDOW)) {
    ::SetWindowLongPtr(window, GWL_STYLE, style | WS_OVERLAPPEDWINDOW);
    if (::IsZoomed(window)) {
      // Refresh the parent window.
      ::SetWindowPos(window, nullptr, 0, 0, 0, 0,
                     SWP_NOACTIVATE | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                         SWP_FRAMECHANGED);
      auto rect = RECT{};
      ::GetClientRect(window, &rect);
      auto flutter_view =
          ::FindWindowEx(window, nullptr, kFlutterViewWindowClassName, nullptr);
      ::SetWindowPos(flutter_view, nullptr, rect.left, rect.top,
                     rect.right - rect.left, rect.bottom - rect.top,
                     SWP_NOACTIVATE | SWP_NOZORDER);
    } else {
      ::SetWindowPos(
          window, nullptr, rect_before_fullscreen_.left,
          rect_before_fullscreen_.top,
          rect_before_fullscreen_.right - rect_before_fullscreen_.left,
          rect_before_fullscreen_.bottom - rect_before_fullscreen_.top,
          SWP_NOACTIVATE | SWP_NOZORDER);
    }
  }
}

RTL_OSVERSIONINFOW Utils::GetWindowsVersion() {
  HMODULE handle = ::LoadLibraryW(L"ntdll.dll");
  RTL_OSVERSIONINFOW rtl_os_version_info = {0};
  rtl_os_version_info.dwBuildNumber = 0;
  rtl_os_version_info.dwOSVersionInfoSize = sizeof(rtl_os_version_info);
  if (handle) {
    RtlGetVersionPtr rtl_get_version_ptr = reinterpret_cast<RtlGetVersionPtr>(
        ::GetProcAddress(handle, "RtlGetVersion"));
    if (rtl_get_version_ptr != nullptr) {
      rtl_get_version_ptr(&rtl_os_version_info);
    }
    ::FreeLibrary(handle);
  }
  return rtl_os_version_info;
}

bool Utils::IsWindows10RTMOrGreater() {
  return GetWindowsVersion().dwBuildNumber >= 10240;
}

bool Utils::fullscreen_ = false;

RECT Utils::rect_before_fullscreen_ = RECT{};
