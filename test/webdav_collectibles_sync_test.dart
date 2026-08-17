import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/hive_registrar.g.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/webdav.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory supportDirectory;
  late Directory hiveDirectory;
  late Directory webDavTempDirectory;
  late Box<CollectedBangumi> collectiblesBox;
  late Box<CollectedBangumiChange> changesBox;
  late _FakeWebDavClient fakeClient;
  late WebDav webDavSync;
  var remoteBoxId = 0;

  setUpAll(() async {
    supportDirectory =
        await Directory.systemTemp.createTemp('kazumi_webdav_collectibles_');
    hiveDirectory = Directory('${supportDirectory.path}/hive');
    webDavTempDirectory = Directory('${supportDirectory.path}/webdavTemp');
    await hiveDirectory.create(recursive: true);
    await webDavTempDirectory.create(recursive: true);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationSupportDirectory') {
        return supportDirectory.path;
      }
      return null;
    });

    Hive.init(hiveDirectory.path);
    Hive.registerAdapters();
    collectiblesBox = await Hive.openBox<CollectedBangumi>('collectibles');
    changesBox = await Hive.openBox<CollectedBangumiChange>('collectchanges');
    GStorage.collectibles = collectiblesBox;
    GStorage.collectChanges = changesBox;

    fakeClient = _FakeWebDavClient();
    webDavSync = WebDav()
      ..client = fakeClient
      ..webDavLocalTempDirectory = webDavTempDirectory;
  });

  setUp(() async {
    await collectiblesBox.clear();
    await changesBox.clear();
    fakeClient.reset();
    if (await webDavTempDirectory.exists()) {
      await webDavTempDirectory.delete(recursive: true);
    }
    await webDavTempDirectory.create(recursive: true);
  });

  tearDown(() async {
    for (final name in const [
      'tempCollectiblesBox',
      'tempCollectChangesBox',
    ]) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).close();
      }
    }
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await Hive.close();
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  Future<List<int>> buildRemoteBox<T>(Map<int, T> values) async {
    final name = 'remoteBox${remoteBoxId++}';
    final box = await Hive.openBox<T>(name);
    await box.putAll(values);
    await box.flush();
    await box.close();
    return File('${hiveDirectory.path}/$name.hive').readAsBytes();
  }

  Future<void> putLocalCollectible({bool withAddChange = false}) async {
    await collectiblesBox.put(1, _collect(1));
    if (withAddChange) {
      await changesBox.put(100, _change(100, 1, 1));
    }
    await collectiblesBox.flush();
    await changesBox.flush();
  }

  test('remote empty initializes from local without deleting collectibles',
      () async {
    await putLocalCollectible();

    await webDavSync.syncCollectibles();

    expect(collectiblesBox.keys, [1]);
    expect(fakeClient.files, contains('/kazumiSync/collectibles.tmp'));
  });

  test('corrupt remote snapshot fails without changing local collectibles',
      () async {
    await putLocalCollectible();
    fakeClient.files['/kazumiSync/collectibles.tmp'] = [1, 2, 3, 4];

    await expectLater(webDavSync.syncCollectibles(), throwsA(anything));

    expect(collectiblesBox.keys, [1]);
    expect(fakeClient.uploadCount, 0);
  });

  test('snapshot-only remote keeps locally logged additions', () async {
    await putLocalCollectible(withAddChange: true);
    fakeClient.files['/kazumiSync/collectibles.tmp'] =
        await buildRemoteBox<CollectedBangumi>({2: _collect(2)});

    await webDavSync.syncCollectibles();

    expect(collectiblesBox.keys.toSet(), {1, 2});
  });

  test('changes without snapshot fail closed and preserve local collectibles',
      () async {
    await putLocalCollectible();
    fakeClient.files['/kazumiSync/collectchanges.tmp'] =
        await buildRemoteBox<CollectedBangumiChange>({
      101: _change(101, 1, 3),
    });

    await expectLater(
      webDavSync.syncCollectibles(),
      throwsA(isA<StateError>()),
    );

    expect(collectiblesBox.keys, [1]);
    expect(fakeClient.uploadCount, 0);
  });

  test('download interruption fails without changing local collectibles',
      () async {
    await putLocalCollectible();
    fakeClient.files['/kazumiSync/collectibles.tmp'] =
        await buildRemoteBox<CollectedBangumi>({2: _collect(2)});
    fakeClient.failDownloads.add('/kazumiSync/collectibles.tmp');

    await expectLater(webDavSync.syncCollectibles(), throwsA(anything));

    expect(collectiblesBox.keys, [1]);
    expect(fakeClient.uploadCount, 0);
  });

  test('complete remote snapshot still applies a legitimate remote deletion',
      () async {
    await putLocalCollectible(withAddChange: true);
    fakeClient.files['/kazumiSync/collectibles.tmp'] =
        await buildRemoteBox<CollectedBangumi>({});
    fakeClient.files['/kazumiSync/collectchanges.tmp'] =
        await buildRemoteBox<CollectedBangumiChange>({
      100: _change(100, 1, 1),
      101: _change(101, 1, 3),
    });

    await webDavSync.syncCollectibles();

    expect(collectiblesBox.values, isEmpty);
  });
}

class _FakeWebDavClient extends webdav.Client {
  _FakeWebDavClient()
      : super(
          uri: 'https://example.invalid',
          c: webdav.WdDio(),
          auth: const webdav.Auth(user: '', pwd: ''),
        );

  final Map<String, List<int>> files = {};
  final Set<String> failDownloads = {};
  int uploadCount = 0;

  void reset() {
    files.clear();
    failDownloads.clear();
    uploadCount = 0;
  }

  @override
  Future<List<webdav.File>> readDir(String path, [dynamic cancelToken]) async {
    final prefix = path == '/' ? '/' : '$path/';
    return files.keys
        .where((filePath) => filePath.startsWith(prefix))
        .map((filePath) => filePath.substring(prefix.length))
        .where((name) => name.isNotEmpty && !name.contains('/'))
        .map((name) => webdav.File(name: name, isDir: false))
        .toList();
  }

  @override
  Future<void> read2File(
    String path,
    String savePath, {
    void Function(int count, int total)? onProgress,
    dynamic cancelToken,
  }) async {
    if (failDownloads.contains(path)) {
      throw const FileSystemException('injected download interruption');
    }
    final bytes = files[path];
    if (bytes == null) {
      throw FileSystemException('missing fake remote file', path);
    }
    final file = File(savePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> writeFromFile(
    String localFilePath,
    String path, {
    void Function(int count, int total)? onProgress,
    dynamic cancelToken,
  }) async {
    uploadCount++;
    files[path] = await File(localFilePath).readAsBytes();
  }

  @override
  Future<void> remove(String path, [dynamic cancelToken]) async {
    files.remove(path);
  }

  @override
  Future<void> rename(
    String oldPath,
    String newPath,
    bool overwrite, [
    dynamic cancelToken,
  ]) async {
    final bytes = files.remove(oldPath);
    if (bytes == null) {
      throw FileSystemException('missing fake remote file', oldPath);
    }
    files[newPath] = bytes;
  }
}

CollectedBangumi _collect(int id) {
  return CollectedBangumi(
    BangumiItem(
      id: id,
      type: 2,
      name: 'subject $id',
      nameCn: '条目 $id',
      summary: '',
      airDate: '2026-01-01',
      airWeekday: 4,
      rank: 0,
      images: const {
        'large': '',
        'common': '',
        'medium': '',
        'small': '',
        'grid': '',
      },
      tags: const <BangumiTag>[],
      alias: const [],
      ratingScore: 0,
      votes: 0,
      votesCount: const [],
      info: '',
    ),
    DateTime.utc(2026, 1, id),
    CollectType.watching.value,
  );
}

CollectedBangumiChange _change(int id, int bangumiId, int action) {
  return CollectedBangumiChange(
    id,
    bangumiId,
    action,
    CollectType.watching.value,
    id,
  );
}
