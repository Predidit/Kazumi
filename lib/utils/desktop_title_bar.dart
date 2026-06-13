import 'dart:io';

import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/device.dart';
import 'package:window_manager/window_manager.dart';

class DesktopTitleBar {
  DesktopTitleBar._();

  static bool _storedValue() => GStorage.getSetting(SettingsKeys.showWindowButton);

  /// Migrates legacy Windows [SettingsKeys.showWindowButton] values after the
  /// custom title bar change. Old `true` meant "use system title bar"; new
  /// Windows builds always hide the native bar and invert the stored flag for
  /// custom title bar visibility. Without migration, upgraded users who had
  /// enabled the system title bar would see no title bar at all.
  static Future<void> migrateLegacySettingsIfNeeded() async {
    if (!Platform.isWindows) return;
    if (GStorage.getSetting(SettingsKeys.windowsCustomTitleBarMigrated)) {
      return;
    }

    if (_storedValue()) {
      await GStorage.putSetting(SettingsKeys.showWindowButton, false);
    }
    await GStorage.putSetting(SettingsKeys.windowsCustomTitleBarMigrated, true);
  }

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
