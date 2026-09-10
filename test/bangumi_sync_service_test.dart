import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/collect/collect_sync_plan.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/request/clients/bangumi_client.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/services/collection/collection_service.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/bangumi_sync_service.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  final bangumi = BangumiSyncService();
  late Directory directory;
  late PathProviderPlatform originalPathProvider;
  late _BangumiAdapter adapter;

  setUpAll(() async {
    Logger.level = Level.off;
    directory = await Directory.systemTemp.createTemp('kazumi_bangumi_test_');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
    Hive.init(directory.path);
    await GStorage.init();
  });

  setUp(() async {
    bangumi.resetForTesting();
    await GStorage.putSetting(SettingsKeys.bangumiAccessToken, 'saved-token');
    await GStorage.putSetting(SettingsKeys.bangumiSyncEnable, true);
    await GStorage.putSetting(SettingsKeys.enableBangumiProxy, false);
    await GStorage.collection.replace([], []);
    DioFactory.reset();
    adapter = _BangumiAdapter();
    DioFactory.apiDio.httpClientAdapter = adapter;
  });

  tearDownAll(() async {
    DioFactory.apiDio.close(force: true);
    DioFactory.reset();
    await Hive.close();
    PathProviderPlatform.instance = originalPathProvider;
    final testRoot = directory.absolute.path;
    expect(testRoot.startsWith(Directory.systemTemp.absolute.path), isTrue);
    expect(directory.uri.pathSegments.where((part) => part.isNotEmpty).last,
        startsWith('kazumi_bangumi_test_'));
    await directory.delete(recursive: true);
  });

  test('startup connection failure preserves enabled preference and can retry',
      () async {
    adapter.respond = (request) => throw DioException(
          requestOptions: request,
          type: DioExceptionType.connectionTimeout,
        );
    await expectLater(bangumi.ping(), throwsA(isA<NetworkException>()));
    expect(GStorage.getSetting(SettingsKeys.bangumiSyncEnable), isTrue);
    expect(bangumi.initialized, isFalse);
    expect(bangumi.isConnecting, isFalse);
    expect(bangumi.lastError, contains('超时'));

    adapter.respond = (_) async => _user();
    await bangumi.ping();
    expect(bangumi.initialized, isTrue);
    expect(bangumi.username, 'saved-user');
    expect(bangumi.lastError, isNull);
  });

  test('enabling sends authorization while sync is disabled', () async {
    await GStorage.putSetting(SettingsKeys.bangumiSyncEnable, false);
    await bangumi.setEnabled(true);
    expect(
        adapter.requests.single.headers['Authorization'], 'Bearer saved-token');
    expect(GStorage.getSetting(SettingsKeys.bangumiSyncEnable), isTrue);
  });

  test('failed draft validation preserves credentials and connected account',
      () async {
    await bangumi.ping();
    adapter.respond = (_) async => _json({}, status: 401);
    await expectLater(
        bangumi.saveToken('invalid-draft'), throwsA(isA<NetworkException>()));
    expect(
        adapter.requests.last.headers['Authorization'], 'Bearer invalid-draft');
    expect(GStorage.getSetting(SettingsKeys.bangumiAccessToken), 'saved-token');
    expect(GStorage.getSetting(SettingsKeys.bangumiSyncEnable), isTrue);
    expect(bangumi.initialized, isTrue);
    expect(bangumi.username, 'saved-user');
    expect(bangumi.isConnecting, isFalse);
  });

  test('draft validation is isolated and only commits after success', () async {
    final response = Completer<ResponseBody>();
    final started = Completer<void>();
    adapter.respond = (request) async {
      if (request.uri.path == '/v0/me') {
        started.complete();
        return response.future;
      }
      return _json({});
    };
    final saving = bangumi.saveToken('  replacement-token  ');
    await started.future;
    expect(GStorage.getSetting(SettingsKeys.bangumiAccessToken), 'saved-token');
    await BangumiClient.instance.get('https://api.bgm.tv/v0/subjects/1');
    expect(
        adapter.requests.last.headers['Authorization'], 'Bearer saved-token');
    response.complete(_user('replacement-user'));
    await saving;
    expect(GStorage.getSetting(SettingsKeys.bangumiAccessToken),
        'replacement-token');
    expect(bangumi.username, 'replacement-user');
    expect(GStorage.getSetting(SettingsKeys.bangumiSyncEnable), isTrue);
  });

  test('revalidating an expired saved token updates status without disabling',
      () async {
    await bangumi.ping();
    adapter.respond = (_) async => _json({}, status: 401);
    await expectLater(
        bangumi.saveToken('saved-token'), throwsA(isA<NetworkException>()));
    expect(bangumi.initialized, isFalse);
    expect(bangumi.lastError, contains('无效或已过期'));
    expect(GStorage.getSetting(SettingsKeys.bangumiAccessToken), 'saved-token');
    expect(GStorage.getSetting(SettingsKeys.bangumiSyncEnable), isTrue);
  });

  test('saving a token while disabled does not enable sync', () async {
    await GStorage.putSetting(SettingsKeys.bangumiSyncEnable, false);
    await bangumi.saveToken('replacement-token');
    expect(bangumi.initialized, isTrue);
    expect(GStorage.getSetting(SettingsKeys.bangumiSyncEnable), isFalse);
  });

  test('empty draft does not erase the saved token', () async {
    await expectLater(bangumi.saveToken('   '), throwsStateError);
    expect(GStorage.getSetting(SettingsKeys.bangumiAccessToken), 'saved-token');
    expect(adapter.requests, isEmpty);
    expect(bangumi.isConnecting, isFalse);
  });

  for (final status in [401, 403, 429, 503]) {
    test('HTTP $status leaves a persistent actionable connection error',
        () async {
      adapter.respond = (_) async => _json({}, status: status);
      await expectLater(bangumi.ping(), throwsA(isA<NetworkException>()));
      expect(GStorage.getSetting(SettingsKeys.bangumiSyncEnable), isTrue);
      expect(
          bangumi.lastError,
          contains(switch (status) {
            401 => '无效或已过期',
            403 => '拒绝访问',
            429 => '请求过于频繁',
            _ => 'HTTP 503',
          }));
    });
  }

  test('malformed user response does not enable sync', () async {
    await GStorage.putSetting(SettingsKeys.bangumiSyncEnable, false);
    adapter.respond = (_) async => _json({'id': 123, 'avatar': {}});
    await expectLater(bangumi.setEnabled(true), throwsFormatException);
    expect(bangumi.lastError, contains('格式异常'));
    expect(GStorage.getSetting(SettingsKeys.bangumiSyncEnable), isFalse);
  });

  test('busy connection checks serialize without clearing a valid session',
      () async {
    await bangumi.ping();
    final response = Completer<void>();
    final started = Completer<void>();
    adapter.respond = (_) async {
      if (!started.isCompleted) started.complete();
      await response.future;
      return _user();
    };
    final first = bangumi.ping();
    await started.future;
    final second = bangumi.ping();
    expect(bangumi.initialized, isTrue);
    expect(bangumi.username, 'saved-user');
    response.complete();
    await Future.wait([first, second]);
    expect(bangumi.initialized, isTrue);
  });

  test('immediate sync reconnects after initialization failure', () async {
    adapter.respond = (_) async => _json({}, status: 503);
    await expectLater(bangumi.ping(), throwsA(isA<NetworkException>()));
    adapter.respond =
        (request) async => request.method == 'POST' ? _json({}) : _user();
    expect(await bangumi.updateCollectible(123, 1), isTrue);
    expect(adapter.requests.last.method, 'POST');
    expect(bangumi.initialized, isTrue);
    expect(bangumi.lastError, isNull);
  });

  test('manual collection sync reconnects instead of rejecting uninitialized',
      () async {
    adapter.respond = (request) async => request.uri.path == '/v0/me'
        ? _user()
        : _json({'data': [], 'total': 0, 'limit': 50});
    final updates = <CollectSyncUpdate>[];
    final service = CollectionService(CollectRepository());
    addTearDown(service.dispose);
    final controller = CollectController(service);
    addTearDown(controller.dispose);
    await controller.syncAll(
        const CollectSyncPlan(
          webDavEnabled: false,
          webDavCollectiblesEnabled: false,
          bangumiEnabled: true,
        ),
        onUpdate: updates.add);
    expect(updates.last.status, CollectSyncStatus.succeeded);
    expect(bangumi.initialized, isTrue);
  });

  test('queued disable prevents subsequent full sync requests', () async {
    final response = Completer<ResponseBody>();
    final started = Completer<void>();
    adapter.respond = (_) {
      started.complete();
      return response.future;
    };
    final connecting = bangumi.ping();
    await started.future;
    final disabling = bangumi.setEnabled(false);
    final service = CollectionService(CollectRepository());
    addTearDown(service.dispose);
    final syncing = expectLater(service.syncBangumi(), throwsStateError);
    response.complete(_user());
    await Future.wait([connecting, disabling, syncing]);
    expect(GStorage.getSetting(SettingsKeys.bangumiSyncEnable), isFalse);
    expect(adapter.requests, hasLength(1));
  });
}

ResponseBody _json(Object data, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );

ResponseBody _user([String username = 'saved-user']) => _json({
      'id': 123,
      'username': username,
      'avatar': <String, String>{},
    });

class _BangumiAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Future<ResponseBody> Function(RequestOptions) respond = (_) async => _user();

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
