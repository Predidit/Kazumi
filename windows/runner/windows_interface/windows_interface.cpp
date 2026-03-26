#include "windows_interface.h"

#include <algorithm>
#include <optional>
#include <flutter/standard_method_codec.h>
#include <windowsx.h>

namespace {

std::optional<int64_t> ToInt64(const flutter::EncodableValue& value) {
  if (const auto* int32_value = std::get_if<int32_t>(&value)) {
    return static_cast<int64_t>(*int32_value);
  }
  if (const auto* int64_value = std::get_if<int64_t>(&value)) {
    return *int64_value;
  }
  if (const auto* double_value = std::get_if<double>(&value)) {
    return static_cast<int64_t>(*double_value);
  }
  return std::nullopt;
}

std::optional<bool> ToBool(const flutter::EncodableValue& value) {
  if (const auto* bool_value = std::get_if<bool>(&value)) {
    return *bool_value;
  }
  return std::nullopt;
}

}  // namespace

std::unique_ptr<WindowsInterface> WindowsInterface::instance_ = nullptr;

void WindowsInterface::RegisterPlugin(flutter::FlutterEngine* engine,
                                      HWND flutter_hwnd) {
  if (instance_ != nullptr) {
    return;
  }
  instance_ = std::unique_ptr<WindowsInterface>(
      new WindowsInterface(engine, flutter_hwnd));
}

WindowsInterface::WindowsInterface(flutter::FlutterEngine* engine,
                                   HWND flutter_hwnd)
    : flutter_hwnd_(flutter_hwnd) {
  RegisterChannel(engine);
  old_wnd_proc_ = reinterpret_cast<WNDPROC>(SetWindowLongPtr(
      flutter_hwnd_, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(WndProc)));
}

WindowsInterface::~WindowsInterface() {
  if (flutter_hwnd_ != nullptr && old_wnd_proc_ != nullptr) {
    SetWindowLongPtr(flutter_hwnd_, GWLP_WNDPROC,
                     reinterpret_cast<LONG_PTR>(old_wnd_proc_));
    old_wnd_proc_ = nullptr;
  }
}

void WindowsInterface::RegisterChannel(flutter::FlutterEngine* engine) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "com.predidit.kazumi/windows_interface",
      &flutter::StandardMethodCodec::GetInstance());

  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name().compare("setWindowsTitleHeight") == 0) {
      if (!call.arguments()) {
        result->Error("InvalidArguments", "Missing title height");
        return;
      }
      std::optional<int64_t> height = ToInt64(*call.arguments());
      if (!height.has_value()) {
        result->Error("InvalidArguments", "Title height must be a number");
        return;
      }
      SetWindowsTitleHeight(height.value());
      result->Success();
      return;
    }

    if (call.method_name().compare("setWindowsTitleButtonWidth") == 0) {
      if (!call.arguments()) {
        result->Error("InvalidArguments", "Missing title button width");
        return;
      }
      std::optional<int64_t> width = ToInt64(*call.arguments());
      if (!width.has_value()) {
        result->Error("InvalidArguments",
                      "Title button width must be a number");
        return;
      }
      SetWindowsTitleButtonWidth(width.value());
      result->Success();
      return;
    }

    if (call.method_name().compare("setWindowsTitleTopInset") == 0) {
      if (!call.arguments()) {
        result->Error("InvalidArguments", "Missing title top inset");
        return;
      }
      std::optional<int64_t> inset = ToInt64(*call.arguments());
      if (!inset.has_value()) {
        result->Error("InvalidArguments", "Title top inset must be a number");
        return;
      }
      SetWindowsTitleTopInset(inset.value());
      result->Success();
      return;
    }

    if (call.method_name().compare("setWindowsTitleBarEnabled") == 0) {
      if (!call.arguments()) {
        result->Error("InvalidArguments", "Missing enabled flag");
        return;
      }
      std::optional<bool> enabled = ToBool(*call.arguments());
      if (!enabled.has_value()) {
        result->Error("InvalidArguments", "Enabled flag must be bool");
        return;
      }
      SetEnabled(enabled.value());
      result->Success();
      return;
    }

    result->NotImplemented();
  });
}

LRESULT CALLBACK WindowsInterface::WndProc(HWND hWnd, UINT message,
                                           WPARAM wParam, LPARAM lParam) {
  if (instance_ == nullptr || hWnd != instance_->flutter_hwnd_) {
    return DefWindowProc(hWnd, message, wParam, lParam);
  }
  return instance_->HandleMessage(hWnd, message, wParam, lParam);
}

LRESULT WindowsInterface::HandleMessage(HWND hWnd, UINT message, WPARAM wParam,
                                        LPARAM lParam) {
  if (!enabled_) {
    return CallWindowProc(old_wnd_proc_, hWnd, message, wParam, lParam);
  }

  switch (message) {
    case WM_NCHITTEST: {
      UpdateTitleButtonStatus(hWnd, lParam);
      if (title_bar_hovered_button_ == CustomTitleBarHoveredButton_Maximize) {
        return HTMAXBUTTON;
      } else if (title_bar_hovered_button_ ==
                 CustomTitleBarHoveredButton_Minimize) {
        return HTMINBUTTON;
      } else if (title_bar_hovered_button_ == CustomTitleBarHoveredButton_Close) {
        return HTCLOSE;
      }
      return HTCLIENT;
    }
    case WM_NCMOUSEMOVE:
    case WM_MOUSEMOVE: {
      UpdateTitleButtonStatus(hWnd, lParam);
      TRACKMOUSEEVENT track_event{
          sizeof(TRACKMOUSEEVENT), TME_LEAVE, hWnd, HOVER_DEFAULT};
      TrackMouseEvent(&track_event);
      break;
    }
    case WM_MOUSELEAVE:
    case WM_NCMOUSELEAVE: {
      if (title_bar_hovered_button_ != CustomTitleBarHoveredButton_None) {
        title_bar_hovered_button_ = CustomTitleBarHoveredButton_None;
        OnTitleButtonHover();
      }
      break;
    }
    case WM_NCLBUTTONDOWN: {
      if (title_bar_hovered_button_ != CustomTitleBarHoveredButton_None) {
        OnTitleButtonDown();
        title_bar_down_button_ = title_bar_hovered_button_;
        return HTNOWHERE;
      }
      break;
    }
    case WM_NCLBUTTONUP: {
      if (title_bar_hovered_button_ != CustomTitleBarHoveredButton_None) {
        OnTitleButtonUp();
        if (title_bar_hovered_button_ == title_bar_down_button_) {
          OnTitleButtonClick();
        }
        title_bar_down_button_ = CustomTitleBarHoveredButton_None;
        return HTNOWHERE;
      }
      title_bar_down_button_ = CustomTitleBarHoveredButton_None;
      break;
    }
    default:
      break;
  }

  return CallWindowProc(old_wnd_proc_, hWnd, message, wParam, lParam);
}

void WindowsInterface::UpdateTitleButtonStatus(HWND hWnd, LPARAM lParam) {
  CustomTitleBarHoveredButton button = HitTestTitleBarButton(hWnd, lParam);
  if (button == title_bar_hovered_button_) {
    return;
  }
  title_bar_hovered_button_ = button;
  OnTitleButtonHover();
}

CustomTitleBarHoveredButton WindowsInterface::HitTestTitleBarButton(
    HWND hWnd, LPARAM lParam) const {
  if (windows_title_height_ <= 0 || windows_title_button_width_ <= 0) {
    return CustomTitleBarHoveredButton_None;
  }

  POINT cursor = {GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)};
  if (!ScreenToClient(hWnd, &cursor)) {
    return CustomTitleBarHoveredButton_None;
  }

  RECT client_rect{};
  if (!GetClientRect(hWnd, &client_rect)) {
    return CustomTitleBarHoveredButton_None;
  }

  const int top = windows_title_top_inset_;
  const int bottom = top + windows_title_height_;
  if (cursor.y < top || cursor.y >= bottom) {
    return CustomTitleBarHoveredButton_None;
  }

  const int right_distance = client_rect.right - cursor.x;
  if (right_distance <= 0) {
    return CustomTitleBarHoveredButton_None;
  }

  if (right_distance <= windows_title_button_width_) {
    return CustomTitleBarHoveredButton_Close;
  }
  if (right_distance <= windows_title_button_width_ * 2) {
    return CustomTitleBarHoveredButton_Maximize;
  }
  if (right_distance <= windows_title_button_width_ * 3) {
    return CustomTitleBarHoveredButton_Minimize;
  }
  return CustomTitleBarHoveredButton_None;
}

void WindowsInterface::OnTitleButtonHover() {
  channel_->InvokeMethod(
      "onTitleButtonHover",
      std::make_unique<flutter::EncodableValue>(
          static_cast<int32_t>(title_bar_hovered_button_)));
}

void WindowsInterface::OnTitleButtonDown() {
  channel_->InvokeMethod(
      "onTitleButtonDown",
      std::make_unique<flutter::EncodableValue>(
          static_cast<int32_t>(title_bar_hovered_button_)));
}

void WindowsInterface::OnTitleButtonUp() {
  channel_->InvokeMethod(
      "onTitleButtonUp",
      std::make_unique<flutter::EncodableValue>(
          static_cast<int32_t>(title_bar_hovered_button_)));
}

void WindowsInterface::OnTitleButtonClick() {
  channel_->InvokeMethod(
      "onTitleButtonClick",
      std::make_unique<flutter::EncodableValue>(
          static_cast<int32_t>(title_bar_hovered_button_)));
}

void WindowsInterface::SetWindowsTitleHeight(int64_t height) {
  windows_title_height_ = static_cast<int32_t>(std::max<int64_t>(0, height));
}

void WindowsInterface::SetWindowsTitleButtonWidth(int64_t width) {
  windows_title_button_width_ =
      static_cast<int32_t>(std::max<int64_t>(0, width));
}

void WindowsInterface::SetWindowsTitleTopInset(int64_t inset) {
  windows_title_top_inset_ = static_cast<int32_t>(std::max<int64_t>(0, inset));
}

void WindowsInterface::SetEnabled(bool enabled) {
  enabled_ = enabled;
  if (!enabled_) {
    title_bar_hovered_button_ = CustomTitleBarHoveredButton_None;
    title_bar_down_button_ = CustomTitleBarHoveredButton_None;
    OnTitleButtonHover();
  }
}
