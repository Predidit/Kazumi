import 'dart:io';

import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/device.dart';
import 'package:window_manager/window_manager.dart';

class DesktopTitleBar {
  DesktopTitleBar._();

  static bool _storedValue() => GStorage.getSetting(SettingsKeys.showWindowButton);

  static bool isVisible() {
    final stored = _storedValue();
    if (Platform.isWindows) {
      return !stored;
    }
    return stored;
  }

  static bool shouldShowCloseButton() {
    return isDesktop() && !isVisible();
  }

  static bool readShowTitleBarSetting() => isVisible();

  static Future<void> saveShowTitleBarSetting(bool showTitleBar) async {
    final stored = Platform.isWindows ? !showTitleBar : showTitleBar;
    await GStorage.putSetting(SettingsKeys.showWindowButton, stored);
  }

  static TitleBarStyle get nativeTitleBarStyle {
    if (Platform.isMacOS || Platform.isWindows) {
      return TitleBarStyle.hidden;
    }
    return isVisible() ? TitleBarStyle.normal : TitleBarStyle.hidden;
  }

  static bool get nativeWindowButtonVisibility {
    if (Platform.isWindows) return false;
    return isVisible();
  }
}
