#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// 1. Include the bitsdojo header
#include <bitsdojo_window_windows/bitsdojo_window_plugin.h>

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // 2. Configure the window on startup
  // BDW_CUSTOM_FRAME: We draw the frame
  // BDW_HIDE_ON_STARTUP: Wait until Flutter renders to show window (prevents white flash)
  auto bdw = bitsdojo_window_configure(BDW_CUSTOM_FRAME | BDW_HIDE_ON_STARTUP);
  (void)bdw; // <-- FIX: Explicitly cast to void to silence "unused variable" error.

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that popups for file open/save dialogs work.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);

  if (!window.Create(L"code_combiner", origin, size)) {
    return EXIT_FAILURE;
  }

  window.SetQuitOnClose(true);

  // 3. Let Flutter handle the show command (bitsdojo handles the rest)
  // window.Show(); 

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}