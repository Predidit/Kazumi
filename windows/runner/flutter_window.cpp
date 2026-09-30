#include "flutter_window.h"
#include "fullscreen_utils.h"
#include "external_player_utils.h"
#include "shortcut_utils.h"

#include <optional>
#include <algorithm>
#include <limits>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"

namespace {
using flutter::EncodableMap;
using flutter::EncodableValue;

bool ReadWindowsInt(const EncodableMap& map, const char* key, int64_t& out) {
  const auto it = map.find(EncodableValue(key));
  if (it == map.end()) return false;
  const auto value = it->second.TryGetLongValue();
  if (!value.has_value()) return false;
  if (*value < (std::numeric_limits<int32_t>::min)() ||
      *value > (std::numeric_limits<int32_t>::max)()) {
    return false;
  }
  out = *value;
  return true;
}

bool ParseWindowBounds(const EncodableValue* value, RECT& rect) {
  const auto* map = value ? std::get_if<EncodableMap>(value) : nullptr;
  int64_t x, y, width, height;
  if (!map || !ReadWindowsInt(*map, "x", x) || !ReadWindowsInt(*map, "y", y) ||
      !ReadWindowsInt(*map, "width", width) ||
      !ReadWindowsInt(*map, "height", height))
    return false;
  // Add in 64 bits to avoid signed overflow when constructing the RECT.
  if (width <= 0 || height <= 0 ||
      x + width > (std::numeric_limits<int32_t>::max)() ||
      y + height > (std::numeric_limits<int32_t>::max)())
    return false;
  rect = {static_cast<LONG>(x), static_cast<LONG>(y),
          static_cast<LONG>(x + width), static_cast<LONG>(y + height)};
  return true;
}

bool ReadWindowBounds(HWND window, EncodableValue& bounds) {
  RECT rect;
  if (!GetWindowRect(window, &rect)) return false;
  const int64_t width = static_cast<int64_t>(rect.right) - rect.left;
  const int64_t height = static_cast<int64_t>(rect.bottom) - rect.top;
  if (width <= 0 || height <= 0 ||
      width > (std::numeric_limits<int32_t>::max)() ||
      height > (std::numeric_limits<int32_t>::max)())
    return false;
  // Physical outer bounds avoid plugin logical-coordinate scaling across DPIs.
  bounds = EncodableValue(EncodableMap{
      {EncodableValue("x"), EncodableValue(static_cast<int64_t>(rect.left))},
      {EncodableValue("y"), EncodableValue(static_cast<int64_t>(rect.top))},
      {EncodableValue("width"), EncodableValue(width)},
      {EncodableValue("height"), EncodableValue(height)}});
  return true;
}

bool ApplyWindowBounds(Win32Window& host, const RECT& requested,
                       EncodableValue& applied) {
  const HWND window = host.GetHandle();
  // Dart prepares normal state through the plugin; do not poll or retry messages.
  if (!IsWindow(window) || IsIconic(window) || IsZoomed(window)) return false;
  const HMONITOR monitor =
      MonitorFromRect(&requested, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  if (!monitor || !GetMonitorInfo(monitor, &info)) return false;
  const RECT& work = info.rcWork;
  const int64_t work_width = static_cast<int64_t>(work.right) - work.left;
  const int64_t work_height = static_cast<int64_t>(work.bottom) - work.top;
  if (work_width <= 0 || work_height <= 0) return false;
  // Only cap valid sizes to the work area; default sizes are not a minimum.
  const int64_t width = (std::min)(
      static_cast<int64_t>(requested.right) - requested.left, work_width);
  const int64_t height = (std::min)(
      static_cast<int64_t>(requested.bottom) - requested.top, work_height);
  const int64_t x = (std::clamp)(static_cast<int64_t>(requested.left),
                                 static_cast<int64_t>(work.left),
                                 static_cast<int64_t>(work.right) - width);
  const int64_t y = (std::clamp)(static_cast<int64_t>(requested.top),
                                 static_cast<int64_t>(work.top),
                                 static_cast<int64_t>(work.bottom) - height);
  const RECT target{static_cast<LONG>(x), static_cast<LONG>(y),
                    static_cast<LONG>(x + width),
                    static_cast<LONG>(y + height)};
  if (!host.SetBoundsInPhysicalPixels(target)) {
    return false;
  }
  // Return actual bounds, after the scoped physical restoration has completed.
  // Normal DPI handling resumes before readback; no correction loop is needed.
  return !IsIconic(window) && !IsZoomed(window) &&
         ReadWindowBounds(window, applied);
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Removed automatic window show to let window_manager plugin control visibility
  // This prevents window flashing during startup
  // flutter_controller_->engine()->SetNextFrameCallback([&]() {
  //   this->Show();
  // });

  // Request a new frame and repaint the Flutter view.
  flutter_controller_->ForceRedraw();

  // Register Intent MethodChannel
  RegisterIntentChannel();

  // Register Storage MethodChannel
  RegisterStorageChannel();

  // Register Shortcut MethodChannel
  RegisterShortcutChannel();

  return true;
}

void FlutterWindow::OnDestroy() {
  // The channel uses the engine's messenger and must not outlive it.
  intent_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Observe geometry changes before plugins can consume the message.
  // Send only an invalidation hint, then continue normal message processing
  // so existing window and child layout handling remains intact.
  if (message == WM_WINDOWPOSCHANGED && hwnd == GetHandle() &&
      intent_channel_) {
    const auto* position = reinterpret_cast<const WINDOWPOS*>(lparam);
    if (position && ((position->flags & SWP_NOMOVE) == 0 ||
                     (position->flags & SWP_NOSIZE) == 0)) {
      intent_channel_->InvokeMethod("windowGeometryChanged", nullptr);
    }
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

// Intent MethodChannel setup
void FlutterWindow::RegisterIntentChannel() {
  intent_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.predidit.kazumi/intent",
          &flutter::StandardMethodCodec::GetInstance());

  intent_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    // Use the existing platform-thread channel without storing native mode state.
    if (call.method_name() == "captureWindowGeometry") {
      const HWND window = GetHandle();
      if (!IsWindow(window)) {
        result->Error("WindowGeometryFailed", "Window is unavailable");
        return;
      }
      const bool minimized = IsIconic(window) != FALSE;
      const bool maximized = IsZoomed(window) != FALSE;
      EncodableMap geometry{
          {EncodableValue("isVisible"),
           EncodableValue(IsWindowVisible(window) != FALSE)},
          {EncodableValue("isMinimized"), EncodableValue(minimized)},
          {EncodableValue("isMaximized"), EncodableValue(maximized)}};
      // Maximized bounds must not replace normal bounds.
      // Hidden normal windows can still be read before showing the window at startup.
      if (!minimized && !maximized) {
        EncodableValue bounds;
        if (!ReadWindowBounds(window, bounds)) {
          result->Error("WindowGeometryFailed", "Cannot read normal bounds");
          return;
        }
        geometry[EncodableValue("normalBounds")] = bounds;
      }
      result->Success(EncodableValue(geometry));
    } else if (call.method_name() == "restoreWindowBounds") {
      RECT bounds;
      if (!ParseWindowBounds(call.arguments(), bounds)) {
        result->Error("InvalidArguments", "Invalid physical window bounds");
        return;
      }
      EncodableValue applied;
      if (!ApplyWindowBounds(*this, bounds, applied)) {
        result->Error("WindowBoundsRestoreFailed",
                      "Cannot restore normal bounds");
        return;
      }
      result->Success(applied);
    } else if (call.method_name().compare("enterFullscreen") == 0) {
      FullscreenUtils::EnterNativeFullscreen(GetHandle());
      result->Success();
    } else if (call.method_name().compare("exitFullscreen") == 0) {
      FullscreenUtils::ExitNativeFullscreen(GetHandle());
      result->Success();
    } else if (call.method_name().compare("openWithMime") == 0) {
      const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
      if (arguments) {
        auto url_it = arguments->find(flutter::EncodableValue("url"));
        if (url_it != arguments->end()) {
          const std::string& url = std::get<std::string>(url_it->second);
          ExternalPlayerUtils::OpenWithPlayer(url.c_str());
          result->Success();
        } else {
          result->Error("InvalidArguments", "Missing 'url' argument");
        }
      } else {
        result->Error("InvalidArguments", "Arguments are not a map");
      }
    } else {
      result->NotImplemented();
    }
  });
}

// Storage MethodChannel setup
void FlutterWindow::RegisterStorageChannel() {
  auto storage_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "com.predidit.kazumi/storage",
          &flutter::StandardMethodCodec::GetInstance());

  storage_channel->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name().compare("getAvailableStorage") == 0) {
      std::wstring path = L"C:\\";
      const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
      if (arguments) {
        auto path_it = arguments->find(flutter::EncodableValue("path"));
        if (path_it != arguments->end()) {
          const std::string& path_str = std::get<std::string>(path_it->second);
          // Extract drive root from path (e.g. "C:\Users\..." -> "C:\")
          if (path_str.length() >= 2 && path_str[1] == ':') {
            path = std::wstring(1, static_cast<wchar_t>(path_str[0])) + L":\\";
          }
        }
      }

      ULARGE_INTEGER free_bytes_available;
      if (GetDiskFreeSpaceExW(path.c_str(), &free_bytes_available, nullptr, nullptr)) {
        result->Success(flutter::EncodableValue(static_cast<int64_t>(free_bytes_available.QuadPart)));
      } else {
        result->Success(flutter::EncodableValue(static_cast<int64_t>(-1)));
      }
    } else {
      result->NotImplemented();
    }
  });
}

// Shortcut MethodChannel setup
void FlutterWindow::RegisterShortcutChannel() {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.predidit.kazumi/shortcut",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() != "createDesktopShortcut") {
      result->NotImplemented();
      return;
    }

    bool success = ShortcutUtils::CreateDesktopShortcut(L"Kazumi", L"Kazumi - Anime Player");
    if (success) {
      result->Success(flutter::EncodableValue(true));
    } else {
      result->Error("Failed", "Failed to create desktop shortcut");
    }
  });
}
