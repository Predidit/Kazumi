import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/storage/settings_keys.dart';

void main() {
  group('SettingsKeys.defaultVolume', () {
    test('defaults to full volume (100)', () {
      expect(SettingsKeys.defaultVolume.defaultValue, 100.0);
    });

    test('belongs to the player setting group', () {
      expect(SettingsKeys.defaultVolume.group, SettingGroup.player);
    });

    test('is registered in the global settings list', () {
      expect(SettingsKeys.all, contains(SettingsKeys.defaultVolume));
      expect(
        SettingsKeys.byGroup(SettingGroup.player),
        contains(SettingsKeys.defaultVolume),
      );
    });

    test('uses a stable persisted key name', () {
      expect(SettingsKeys.defaultVolume.name, 'defaultVolume');
    });
  });
}
