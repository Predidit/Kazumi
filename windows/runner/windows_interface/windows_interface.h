#ifndef RUNNER_WINDOWS_INTERFACE_WINDOWS_INTERFACE_H_
#define RUNNER_WINDOWS_INTERFACE_WINDOWS_INTERFACE_H_

#include <flutter/encodable_value.h>
#include <flutter/flutter_engine.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <cstdint>
#include <memory>
#include <windows.h>

enum CustomTitleBarHoveredButton {
  CustomTitleBarHoveredButton_None = 0,
  CustomTitleBarHoveredButton_Minimize = 1,
  CustomTitleBarHoveredButton_Maximize = 2,
  CustomTitleBarHoveredButton_Close = 3,
};

class WindowsInterface {
 public:
  static void RegisterPlugin(flutter::FlutterEngine* engine, HWND flutter_hwnd);

  ~WindowsInterface();

 private:
  WindowsInterface(flutter::FlutterEngine* engine, HWND flutter_hwnd);

  static LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam,
                                  LPARAM lParam);

  LRESULT HandleMessage(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);
  void RegisterChannel(flutter::FlutterEngine* engine);
  void UpdateTitleButtonStatus(HWND hWnd, LPARAM lParam);
  CustomTitleBarHoveredButton HitTestTitleBarButton(HWND hWnd,
                                                     LPARAM lParam) const;

  void OnTitleButtonHover();
  void OnTitleButtonDown();
  void OnTitleButtonUp();
  void OnTitleButtonClick();

  void SetWindowsTitleHeight(int64_t height);
  void SetWindowsTitleButtonWidth(int64_t width);
  void SetWindowsTitleTopInset(int64_t inset);
  void SetEnabled(bool enabled);

  static std::unique_ptr<WindowsInterface> instance_;

  HWND flutter_hwnd_ = nullptr;
  WNDPROC old_wnd_proc_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  CustomTitleBarHoveredButton title_bar_hovered_button_ =
      CustomTitleBarHoveredButton_None;
  CustomTitleBarHoveredButton title_bar_down_button_ =
      CustomTitleBarHoveredButton_None;

  int32_t windows_title_height_ = 32;
  int32_t windows_title_button_width_ = 44;
  int32_t windows_title_top_inset_ = 0;
  bool enabled_ = true;
};

#endif  // RUNNER_WINDOWS_INTERFACE_WINDOWS_INTERFACE_H_
