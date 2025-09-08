#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

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
  // Make sure the application is a single instance.
  // This is important for the application to work correctly with the local storage.
  if (!isSingleInstance())
  {
    MessageBox(NULL, L"Another instance is already running.", L"Error", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
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
