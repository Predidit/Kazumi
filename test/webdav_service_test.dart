import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/danmaku/danmaku_shield_sync.dart';
import 'package:kazumi/repositories/danmaku_shield_repository.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/danmaku_shield_sync_service.dart';
import 'package:kazumi/services/sync/webdav.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

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
    await GStorage.resetSettings([
      SettingsKeys.danmakuShieldSyncDeviceId,
      SettingsKeys.danmakuShieldSyncState,
      SettingsKeys.danmakuShieldSyncCorruptState,
    ]);
    await GStorage.shieldList.clear();
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

  test('disabling WebDAV clears all dependent flags', () async {
    await GStorage.putSetting(SettingsKeys.webDavEnable, true);
    await GStorage.putSetting(SettingsKeys.webDavEnableHistory, true);
    await GStorage.putSetting(SettingsKeys.webDavEnableCollect, true);
    await GStorage.putSetting(SettingsKeys.webDavEnableDanmakuShield, true);

    await webDav.setEnabled(false);

    expect(GStorage.getSetting(SettingsKeys.webDavEnable), isFalse);
    expect(GStorage.getSetting(SettingsKeys.webDavEnableHistory), isFalse);
    expect(GStorage.getSetting(SettingsKeys.webDavEnableCollect), isFalse);
    expect(
        GStorage.getSetting(SettingsKeys.webDavEnableDanmakuShield), isFalse);
  });

  test('failed WebDAV initialization clears the previous connection', () async {
    webDav.initialized = true;

    await expectLater(webDav.init(), throwsException);

    expect(webDav.initialized, isFalse);
    await expectLater(webDav.setEnabled(true), throwsException);
    expect(GStorage.getSetting(SettingsKeys.webDavEnable), isFalse);
  });

  group('danmaku shield sync', () {
    late DanmakuShieldRepository repository;
    late DanmakuShieldSyncService service;
    const deviceA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const deviceB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const root = '/kazumiSync/danmakuShield';
    late _MemoryWebDavClient client;

    Future<void> switchDevice(String id, {String state = ''}) async {
      await GStorage.shieldList.clear();
      await GStorage.putSetting(SettingsKeys.danmakuShieldSyncDeviceId, id);
      await GStorage.putSetting(SettingsKeys.danmakuShieldSyncState, state);
      await repository.initialize();
    }

    DanmakuShieldSyncState uploaded(String id) =>
        DanmakuShieldSyncState.decode(client.files['$root/$id.json']!);

    setUp(() async {
      repository = DanmakuShieldRepository();
      service = DanmakuShieldSyncService(repository, webDav);
      client = _MemoryWebDavClient();
      webDav.client = client;
      webDav.initialized = true;
      webDav.webDavLocalTempDirectory =
          Directory('${directory.path}/webdavTemp');
      await GStorage.putSetting(SettingsKeys.webDavEnable, true);
      await GStorage.putSetting(SettingsKeys.webDavEnableDanmakuShield, true);
      await GStorage.putSetting(
          SettingsKeys.danmakuShieldSyncDeviceId, deviceA);
    });

    tearDown(() async {
      await service.dispose();
      await repository.dispose();
    });

    test(
        'uploads existing rules on first sync and imports them on a new device',
        () async {
      await GStorage.shieldList.putAll({'剧透': '剧透', '/广告+/': '/广告+/'});

      await service.sync();

      expect(uploaded(deviceA).rules, unorderedEquals(['剧透', '/广告+/']));
      expect(client.files.keys, ['$root/$deviceA.json']);
      await switchDevice(deviceB);
      await repository.setRule('引战', deleted: false);
      await service.sync();

      expect(
          GStorage.shieldList.values, unorderedEquals(['剧透', '/广告+/', '引战']));
      expect(uploaded(deviceB).rules, unorderedEquals(['剧透', '/广告+/', '引战']));
      expect(client.files.keys,
          unorderedEquals(['$root/$deviceA.json', '$root/$deviceB.json']));
      expect(await webDav.webDavLocalTempDirectory.list().toList(), isEmpty);
    });

    test('offline deletions propagate to stale devices and allow re-adding',
        () async {
      await repository.setRule('剧透', deleted: false);
      await service.sync();
      final stateA = GStorage.getSetting(SettingsKeys.danmakuShieldSyncState);
      await switchDevice(deviceB);
      await service.sync();

      await GStorage.putSetting(SettingsKeys.webDavEnableDanmakuShield, false);
      await repository.setRule('剧透', deleted: true);
      await service.syncIfEnabled();
      expect(uploaded(deviceB).rules, ['剧透']);
      await GStorage.putSetting(SettingsKeys.webDavEnableDanmakuShield, true);
      await service.sync();
      final stateB = GStorage.getSetting(SettingsKeys.danmakuShieldSyncState);

      await switchDevice(deviceA, state: stateA);
      await service.sync();
      expect(GStorage.shieldList.values, isEmpty);
      expect(uploaded(deviceA).entries['剧透']!.deleted, isTrue);

      await repository.setRule('剧透', deleted: false);
      await service.sync();
      await switchDevice(deviceB, state: stateB);
      await service.sync();
      expect(GStorage.shieldList.values, ['剧透']);
    });

    test('failed upload preserves local changes for retry', () async {
      await repository.setRule('广告', deleted: false);
      await service.sync();
      await repository.setRule('广告', deleted: true);
      client.failUpload = true;

      await expectLater(service.sync(), throwsStateError);

      expect(GStorage.shieldList.values, isEmpty);
      expect(uploaded(deviceA).rules, ['广告']);
      client.failUpload = false;
      await service.sync();
      expect(uploaded(deviceA).rules, isEmpty);
      expect(uploaded(deviceA).entries['广告']!.deleted, isTrue);
      expect(await webDav.webDavLocalTempDirectory.list().toList(), isEmpty);
    });

    test('invalid remote files never partially apply or overwrite data',
        () async {
      await repository.setRule('本地', deleted: false);
      final before = GStorage.getSetting(SettingsKeys.danmakuShieldSyncState);
      client.files['$root/$deviceA.json'] = DanmakuShieldSyncState([
        const DanmakuShieldSyncEntry(
            rule: '远端', updatedAt: 1, deviceId: deviceA, deleted: false),
      ]).encode();
      client.files['$root/$deviceB.json'] = '{invalid';
      final remoteBefore = Map.of(client.files);

      await expectLater(service.sync(), throwsFormatException);

      expect(GStorage.shieldList.values, ['本地']);
      expect(GStorage.getSetting(SettingsKeys.danmakuShieldSyncState), before);
      expect(client.files, remoteBefore);
      expect(await webDav.webDavLocalTempDirectory.list().toList(), isEmpty);
    });

    test('an edit during upload is included in the queued sync', () async {
      await repository.setRule('原有', deleted: false);
      final uploading = Completer<void>();
      final resume = Completer<void>();
      client.beforeUpload = () async {
        client.beforeUpload = null;
        uploading.complete();
        await resume.future;
      };
      final first = service.sync();
      await uploading.future;
      await repository.setRule('新增', deleted: false);
      await repository.setRule('原有', deleted: true);
      final second = service.sync();
      resume.complete();
      await Future.wait([first, second]);

      expect(uploaded(deviceA).rules, ['新增']);
      expect(uploaded(deviceA).entries['原有']!.deleted, isTrue);
      expect(GStorage.shieldList.values, ['新增']);
    });

    test('corrupt sync metadata does not prevent offline edits or restart',
        () async {
      const corrupt = '{"version":1,"entries":[';
      await GStorage.putSetting(SettingsKeys.webDavEnable, false);
      await GStorage.shieldList.put('旧规则', '旧规则');
      await GStorage.putSetting(SettingsKeys.danmakuShieldSyncState, corrupt);

      await repository.setRule('/广告+/', deleted: false);
      await repository.setRule('旧规则', deleted: true);
      expect(repository.getRules(), ['/广告+/']);
      expect(GStorage.getSetting(SettingsKeys.danmakuShieldSyncCorruptState),
          corrupt);

      final restarted = DanmakuShieldRepository();
      addTearDown(restarted.dispose);
      await restarted.initialize();
      expect(restarted.getRules(), ['/广告+/']);
      final saved = DanmakuShieldSyncState.decode(
          GStorage.getSetting(SettingsKeys.danmakuShieldSyncState));
      expect(saved.entries['旧规则']!.deleted, isTrue);
    });
  });
}

class _MemoryWebDavClient implements webdav.Client {
  final files = <String, String>{};
  bool failUpload = false;
  Future<void> Function()? beforeUpload;

  @override
  Future<void> mkdir(String path, [CancelToken? cancelToken]) async {}

  @override
  Future<List<webdav.File>> readDir(String path,
      [CancelToken? cancelToken]) async {
    return [
      for (final entry in files.entries)
        if (entry.key.startsWith('$path/'))
          webdav.File(
              name: entry.key.substring(path.length + 1),
              isDir: false,
              size: entry.value.length),
    ];
  }

  @override
  Future<void> read2File(String path, String savePath,
      {void Function(int, int)? onProgress, CancelToken? cancelToken}) async {
    final contents = files[path];
    if (contents == null) throw StateError('File missing: $path');
    await File(savePath).writeAsString(contents);
  }

  @override
  Future<void> writeFromFile(String localFilePath, String path,
      {void Function(int, int)? onProgress, CancelToken? cancelToken}) async {
    await beforeUpload?.call();
    if (failUpload) throw StateError('Upload failed');
    files[path] = await File(localFilePath).readAsString();
  }

  @override
  Future<void> remove(String path, [CancelToken? cancelToken]) async {
    files.remove(path);
  }

  @override
  Future<void> rename(String oldPath, String newPath, bool overwrite,
      [CancelToken? cancelToken]) async {
    files[newPath] = files.remove(oldPath)!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
