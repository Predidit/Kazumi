import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:kazumi/pages/popular/tv_popular_controller.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/storage/storage.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late TvPopularController controller;
  late List<String> requests;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('category_cache_');
    PathProviderPlatform.instance = _Paths(temp.path);
    Hive.init(temp.path);
    await GStorage.init();
  });
  tearDownAll(() async {
    DioFactory.reset();
    await Hive.close();
    await temp.delete(recursive: true);
  });
  setUp(() async {
    await GStorage.putSetting(SettingsKeys.enableBangumiProxy, true);
    DioFactory.reset();
    controller = TvPopularController();
    requests = [];
    DioFactory.apiDio.interceptors.insert(0,
        InterceptorsWrapper(onRequest: (o, h) {
      requests.add(o.uri.toString());
      h.resolve(Response(requestOptions: o, statusCode: 200, data: {
        'data': [
          {
            'id': requests.length,
            'name': 'sample',
            'rating': {'rank': 1, 'score': 7.0, 'total': 1},
            'images': <String, String>{}
          },
        ]
      }));
    }));
  });

  test('non-TV controller retains upstream request behavior', () async {
    final upstreamController = PopularController();
    upstreamController.setCurrentTag('A');
    await upstreamController.queryBangumiByTag(type: 'init');
    await upstreamController.queryBangumiByTag(type: 'init');
    expect(requests.length, 2);
  });

  Future<void> select(String tag) async {
    controller.setCurrentTag(tag);
    await controller.queryBangumiByTag(type: 'init');
  }

  test('returning to a category restores pages without requesting again',
      () async {
    await select('A');
    await controller.queryBangumiByTag();
    final ids = controller.bangumiList.map((e) => e.id).toList();
    await select('B');
    await select('A');
    expect(requests.length, 3);
    expect(controller.bangumiList.map((e) => e.id), ids);
    expect(controller.isLoadingMore, false);
    await controller.queryBangumiByTag();
    expect(Uri.parse(requests.last).queryParameters['offset'], '2');
  });

  test('least recently used categories are evicted', () async {
    for (var i = 0; i < 8; i++) {
      await select('$i');
    }
    await select('0');
    expect(requests.length, 8);
    await select('8');
    await select('0');
    expect(requests.length, 9);
    await select('1');
    expect(requests.length, 10);
  });

  test('empty or failed results remain retryable', () async {
    DioFactory.apiDio.interceptors.insert(0,
        InterceptorsWrapper(onRequest: (o, h) {
      requests.add('empty');
      h.resolve(
          Response(requestOptions: o, statusCode: 200, data: {'data': []}));
    }));
    await select('empty');
    await select('empty');
    expect(requests.length, 2);
  });
}
