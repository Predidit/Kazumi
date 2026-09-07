import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/webdav.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  final webDav = WebDav();
  late Directory directory;
  late PathProviderPlatform originalPaths;

  setUpAll(() async {
    Logger.level = Level.off;
    directory = await Directory.systemTemp.createTemp('kazumi_webdav_test_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
    Hive.init(directory.path);
    await GStorage.init();
  });

  setUp(() async {
    await GStorage.resetSettings(SettingsKeys.byGroup(SettingGroup.webdav));
    webDav.initialized = false;
  });

  tearDownAll(() async {
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    expect(
        directory.absolute.path.startsWith(Directory.systemTemp.absolute.path),
        isTrue);
    expect(directory.uri.pathSegments.where((part) => part.isNotEmpty).last,
        startsWith('kazumi_webdav_test_'));
    await directory.delete(recursive: true);
  });

  test('disabling WebDAV clears both dependent flags', () async {
    await GStorage.putSetting(SettingsKeys.webDavEnable, true);
    await GStorage.putSetting(SettingsKeys.webDavEnableHistory, true);
    await GStorage.putSetting(SettingsKeys.webDavEnableCollect, true);

    await webDav.setEnabled(false);

    expect(GStorage.getSetting(SettingsKeys.webDavEnable), isFalse);
    expect(GStorage.getSetting(SettingsKeys.webDavEnableHistory), isFalse);
    expect(GStorage.getSetting(SettingsKeys.webDavEnableCollect), isFalse);
  });

  test('failed WebDAV initialization clears the previous connection', () async {
    webDav.initialized = true;

    await expectLater(webDav.init(), throwsException);

    expect(webDav.initialized, isFalse);
    await expectLater(webDav.setEnabled(true), throwsException);
    expect(GStorage.getSetting(SettingsKeys.webDavEnable), isFalse);
  });
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
