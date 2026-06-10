import 'package:kazumi/services/storage/settings_keys.dart';

/// Abstraction over the settings persistence layer.
///
/// Enables unit testing of controllers that depend on [GStorage] — inject
/// a fake implementation through the DI container instead of calling the
/// static facade.
abstract class ISettingsRepository {
  T getSetting<T>(
    SettingKey<T> key, {
    SettingContext context = const SettingContext(),
  });

  Future<void> putSetting<T>(SettingKey<T> key, T value);

  List<String> getStringListSettingByName(
    String key, {
    List<String> defaultValue = const [],
  });

  Future<void> putStringListSettingByName(String key, List<String> value);

  Future<void> resetSettings(Iterable<SettingKey<Object?>> keys);
}
