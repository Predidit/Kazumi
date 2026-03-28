// shortcut_utils.h - Windows desktop shortcut utilities
// Handles both regular executable and MSIX packaged applications

#ifndef SHORTCUT_UTILS_H_
#define SHORTCUT_UTILS_H_

#include <string>
#include <windows.h>

class ShortcutUtils {
 public:
  /// Check if the app is running as an MSIX packaged app
  static bool IsMsixPackage();

  /// Get the AppUserModelID for MSIX packaged apps
  /// Returns empty string if not an MSIX package
  static std::wstring GetAppUserModelId();

  /// Create a desktop shortcut
  /// For regular apps: shortcut points to executable
  /// For MSIX apps: shortcut points to AppUserModelID
  static bool CreateDesktopShortcut(
      const std::wstring& shortcutName,
      const std::wstring& description);

 private:
  /// Create shortcut for regular executable
  static bool CreateExecutableShortcut(
      const std::wstring& shortcutPath,
      const std::wstring& exePath,
      const std::wstring& description);

  /// Create shortcut for MSIX packaged app (using AppUserModelID)
  static bool CreateMsixShortcut(
      const std::wstring& shortcutPath,
      const std::wstring& appUserModelId,
      const std::wstring& description);
};

#endif  // SHORTCUT_UTILS_H_