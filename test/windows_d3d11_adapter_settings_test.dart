import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/storage/settings_keys.dart';

void main() {
  test('Windows D3D11 adapter defaults to the existing automatic path', () {
    expect(SettingsKeys.windowsD3D11AdapterId.defaultValue, isNull);
    expect(SettingsKeys.windowsD3D11AdapterId.group, SettingGroup.player);
    expect(SettingsKeys.all, contains(SettingsKeys.windowsD3D11AdapterId));
  });
}
