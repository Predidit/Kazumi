#include "flutter_window.h"
#include "fullscreen_utils.h"
#include "external_player_utils.h"

#include <optional>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>
#include <shobjidl.h>
#include <shlobj.h>

#include "flutter/generated_plugin_registrant.h"

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

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
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
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
  auto window_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "com.predidit.kazumi/intent",
          &flutter::StandardMethodCodec::GetInstance());

  window_channel->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name().compare("enterFullscreen") == 0) {
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
  auto shortcut_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "com.predidit.kazumi/shortcut",
          &flutter::StandardMethodCodec::GetInstance());

  shortcut_channel->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name().compare("createDesktopShortcut") == 0) {
      // Get arguments
      std::wstring shortcut_name = L"Kazumi";
      std::wstring description = L"Kazumi - Anime Player";

      const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
      if (arguments) {
        auto name_it = arguments->find(flutter::EncodableValue("shortcutName"));
        if (name_it != arguments->end()) {
          const std::string& name_str = std::get<std::string>(name_it->second);
          shortcut_name = std::wstring(name_str.begin(), name_str.end());
        }
        auto desc_it = arguments->find(flutter::EncodableValue("description"));
        if (desc_it != arguments->end()) {
          const std::string& desc_str = std::get<std::string>(desc_it->second);
          description = std::wstring(desc_str.begin(), desc_str.end());
        }
      }

      // Get desktop path
      wchar_t desktop_path[MAX_PATH];
      if (SHGetFolderPathW(NULL, CSIDL_DESKTOP, NULL, 0, desktop_path) != S_OK) {
        result->Error("Failed", "Failed to get desktop path");
        return;
      }

      // Build shortcut full path
      std::wstring shortcut_path = std::wstring(desktop_path) + L"\\";
      shortcut_path += shortcut_name;
      shortcut_path += L".lnk";

      // Check if shortcut already exists
      if (GetFileAttributesW(shortcut_path.c_str()) != INVALID_FILE_ATTRIBUTES) {
        result->Success(flutter::EncodableValue(true));
        return;
      }

      // Get current executable path
      wchar_t exe_path[MAX_PATH];
      GetModuleFileNameW(NULL, exe_path, MAX_PATH);

      // Initialize COM
      HRESULT hr = CoInitialize(NULL);
      if (FAILED(hr)) {
        result->Error("Failed", "Failed to initialize COM");
        return;
      }

      // Create IShellLink object
      IShellLinkW* pShellLink = NULL;
      hr = CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER,
                           IID_IShellLinkW, (void**)&pShellLink);
      if (FAILED(hr)) {
        CoUninitialize();
        result->Error("Failed", "Failed to create IShellLink object");
        return;
      }

      // Set shortcut properties
      pShellLink->SetPath(exe_path);
      pShellLink->SetDescription(description.c_str());

      // Get IPersistFile interface to save the shortcut
      IPersistFile* pPersistFile = NULL;
      hr = pShellLink->QueryInterface(IID_IPersistFile, (void**)&pPersistFile);
      if (FAILED(hr)) {
        pShellLink->Release();
        CoUninitialize();
        result->Error("Failed", "Failed to get IPersistFile interface");
        return;
      }

      // Save the shortcut
      hr = pPersistFile->Save(shortcut_path.c_str(), TRUE);
      pPersistFile->Release();
      pShellLink->Release();
      CoUninitialize();

      if (SUCCEEDED(hr)) {
        result->Success(flutter::EncodableValue(true));
      } else {
        result->Error("Failed", "Failed to save shortcut");
      }
    } else {
      result->NotImplemented();
    }
  });
}
