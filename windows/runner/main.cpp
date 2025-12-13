#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

// recommended by NVIDIA to enable high-performance GPU
extern "C"
{
  __declspec(dllexport) DWORD NvOptimusEnablement = 0x00000001;
}

// recommended by AMD to enable high-performance GPU
extern "C"
{
  __declspec(dllexport) int AmdPowerXpressRequestHighPerformance = 1;
}

HANDLE mutex = NULL;

// Window class name must match the one in win32_window.cpp
constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

// Check if a wide string contains non-ASCII characters
bool ContainsNonAscii(const std::wstring& str) {
  for (wchar_t ch : str) {
    if (ch > 127) {
      return true;
    }
  }
  return false;
}

// Get the directory where the executable is located
std::wstring GetExecutableDirectory() {
  wchar_t path[MAX_PATH];
  DWORD length = ::GetModuleFileNameW(NULL, path, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return L"";
  }
  std::wstring fullPath(path);
  size_t lastSlash = fullPath.find_last_of(L"\\/");
  if (lastSlash != std::wstring::npos) {
    return fullPath.substr(0, lastSlash);
  }
  return fullPath;
}

// Check if the executable path contains non-ASCII characters and show error if so
bool CheckPathForNonAscii() {
  std::wstring exeDir = GetExecutableDirectory();
  if (exeDir.empty()) {
    return true;
  }
  
  if (ContainsNonAscii(exeDir)) {
    // Build error message with Unicode escape sequences
    // Message in Chinese and English explaining the path issue
    std::wstring message = 
      L"Kazumi \u65E0\u6CD5\u5728\u5305\u542B\u975E ASCII \u5B57\u7B26"
      L"\uFF08\u5982\u4E2D\u6587\u3001\u65E5\u6587\u7B49\uFF09"
      L"\u7684\u8DEF\u5F84\u4E2D\u8FD0\u884C\u3002\n\n"
      L"\u5F53\u524D\u8DEF\u5F84\uFF1A\n" + exeDir + L"\n\n"
      L"\u8BF7\u5C06\u7A0B\u5E8F\u79FB\u52A8\u5230\u4EC5\u5305\u542B"
      L"\u82F1\u6587\u5B57\u6BCD\u3001\u6570\u5B57\u548C\u5E38\u89C1"
      L"\u7B26\u53F7\u7684\u76EE\u5F55\u4E2D\uFF0C\u4F8B\u5982\uFF1A\n"
      L"C:\\Program Files\\Kazumi\n\n"
      L"Kazumi cannot run in a path containing non-ASCII characters.\n"
      L"Please move the program to a directory with only ASCII characters.";
    ::MessageBoxW(
      NULL,
      message.c_str(),
      L"\u8DEF\u5F84\u9519\u8BEF / Path Error",
      MB_OK | MB_ICONERROR
    );
    return false;
  }
  return true;
}

bool ActivateExistingWindow()
{
  // Find the existing window by class name
  HWND hwnd = ::FindWindow(kWindowClassName, L"kazumi");
  if (hwnd != NULL)
  {
    // Check if window is hidden (e.g., minimized to tray)
    if (!::IsWindowVisible(hwnd))
    {
      // Show the hidden window
      ::ShowWindow(hwnd, SW_SHOW);
    }
    // If window is minimized, restore it
    else if (::IsIconic(hwnd))
    {
      ::ShowWindow(hwnd, SW_RESTORE);
    }

    // Bring window to foreground
    ::SetForegroundWindow(hwnd);

    // Flash the window to get user's attention
    FLASHWINFO fwi = {0};
    fwi.cbSize = sizeof(FLASHWINFO);
    fwi.hwnd = hwnd;
    fwi.dwFlags = FLASHW_ALL | FLASHW_TIMERNOFG;
    fwi.uCount = 3;
    fwi.dwTimeout = 0;
    ::FlashWindowEx(&fwi);

    return true;
  }
  return false;
}

bool isSingleInstance()
{
  if (mutex != NULL)
  {
    return true;
  }
  std::wstring mutex_str = L"kazumi.win.mutex";
  mutex = ::CreateMutex(NULL, TRUE, mutex_str.c_str());
  if (mutex == NULL || GetLastError() == ERROR_ALREADY_EXISTS)
  {
    CloseHandle(mutex);
    mutex = NULL;
    return false;
  }
  return true;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command)
{
  // Check if the executable path contains non-ASCII characters
  // Flutter engine will silently crash if the path contains non-ASCII characters
  if (!CheckPathForNonAscii())
  {
    return EXIT_FAILURE;
  }

  // Make sure the application is a single instance.
  // This is important for the application to work correctly with the local storage.
  if (!isSingleInstance())
  {
    // Try to activate the existing window instead of showing an error
    ActivateExistingWindow();
    return EXIT_SUCCESS;
  }
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent())
  {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  // Disable thread merge to improve performance
  // Attention: This may impact plugin performance and may be incompatible with future Flutter releases.
  project.set_ui_thread_policy(flutter::UIThreadPolicy::RunOnSeparateThread);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"kazumi", origin, size))
  {
    if (mutex) {
      CloseHandle(mutex);
    }
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0))
  {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (mutex) {
    CloseHandle(mutex);
  }
  return EXIT_SUCCESS;
}
