import 'package:kazumi/services/storage/storage.dart';

abstract final class DesktopWindowConfig {
  /// Captured during window setup; preference changes apply on the next launch.
  static final bool showWindowButton = GStorage.getSetting(
    SettingsKeys.showWindowButton,
  );
}
