import 'package:kazumi/services/storage/interfaces/settings_repository.dart';
import 'package:kazumi/services/storage/settings_keys.dart';
import 'package:kazumi/services/storage/storage.dart';

/// Bridges the static [GStorage] facade to the [ISettingsRepository] interface.
///
/// Register as a singleton in the DI container so controllers that accept an
/// [ISettingsRepository] via constructor injection receive this instance.
/// Tests can substitute [FakeSettingsRepository] for isolated unit tests.
class GStorageSettingsRepository implements ISettingsRepository {
  @override
  T getSetting<T>(SettingKey<T> key, {SettingContext context = const SettingContext()}) {
    return GStorage.getSetting<T>(key, context: context);
  }

  @override
  Future<void> putSetting<T>(SettingKey<T> key, T value) {
    return GStorage.putSetting<T>(key, value);
  }

  @override
  List<String> getStringListSettingByName(String key, {List<String> defaultValue = const []}) {
    return GStorage.getStringListSettingByName(key, defaultValue: defaultValue);
  }

  @override
  Future<void> putStringListSettingByName(String key, List<String> value) {
    return GStorage.putStringListSettingByName(key, value);
  }

  @override
  Future<void> resetSettings(Iterable<SettingKey<Object?>> keys) {
    return GStorage.resetSettings(keys);
  }
}
