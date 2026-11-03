import 'package:kazumi/services/storage/storage.dart';

enum LowMemoryMode {
  auto('auto'),
  always('always'),
  never('never');

  const LowMemoryMode(this._storageValue);

  final String _storageValue;

  static LowMemoryMode get current {
    return switch (GStorage.getSetting(SettingsKeys.lowMemoryPolicy)) {
      'always' => always,
      'never' => never,
      null => GStorage.getSetting(SettingsKeys.lowMemoryMode) ? always : auto,
      _ => auto,
    };
  }

  static Stream<void> watch() => GStorage.watchSettings([
        SettingsKeys.lowMemoryPolicy,
        SettingsKeys.lowMemoryMode,
      ]);

  Future<void> save() =>
      GStorage.putSetting(SettingsKeys.lowMemoryPolicy, _storageValue);

  bool isEnabled({required bool isMetered, bool isLocalPlayback = false}) {
    return switch (this) {
      auto => isMetered && !isLocalPlayback,
      always => true,
      never => false,
    };
  }
}
