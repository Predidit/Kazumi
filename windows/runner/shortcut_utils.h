// shortcut_utils.h - Windows desktop shortcut utilities

#ifndef SHORTCUT_UTILS_H_
#define SHORTCUT_UTILS_H_

#include <string>

class ShortcutUtils {
 public:
  static bool CreateDesktopShortcut(const std::wstring& shortcutName, const std::wstring& description);
};

#endif  // SHORTCUT_UTILS_H_