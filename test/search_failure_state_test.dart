import 'dart:io';
import 'package:kazumi/services/platform/tv_mode.dart';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/repositories/search_history_repository.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late SearchPageController controller;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('kazumi_search_state_');
    PathProviderPlatform.instance = _Paths(temp.path);
    Hive.init(temp.path);
    await GStorage.init();
  });
  tearDownAll(() async {
    DioFactory.reset();
    await Hive.close();
    await temp.delete(recursive: true);
  });
  setUp(() {
    TvMode.setEnabledForTesting(true);
    DioFactory.reset();
    controller =
        SearchPageController(CollectRepository(), SearchHistoryRepository());
  });

  tearDown(() => TvMode.setEnabledForTesting(false));

  test('successful empty search is not a network failure', () async {
    DioFactory.apiDio.interceptors.insert(0,
        InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'data': <dynamic>[]}));
    }));
    await controller.searchBangumi('empty', type: 'init');
    expect(controller.bangumiList, isEmpty);
    expect(controller.hasMoreSearchResults, isFalse);
    expect(controller.isLoading, isFalse);
    expect(controller.isTimeOut, isFalse);
  });

  test('failed search remains retryable without advancing its offset',
      () async {
    var requests = 0;
    final offsets = <dynamic>[];
    DioFactory.apiDio.interceptors.insert(0,
        InterceptorsWrapper(onRequest: (options, handler) {
      offsets.add(options.uri.queryParameters['offset']);
      if (requests++ == 0) {
        handler.reject(DioException(
            requestOptions: options, type: DioExceptionType.connectionTimeout));
      } else {
        handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'data': <dynamic>[]}));
      }
    }));
    await controller.searchBangumi('retry', type: 'init');
    expect(controller.isTimeOut, isTrue);
    expect(controller.isLoading, isFalse);
    expect(controller.hasMoreSearchResults, isTrue);
    await controller.searchBangumi('retry');
    expect(offsets, ['0', '0']);
    expect(controller.isTimeOut, isFalse);
    expect(controller.hasMoreSearchResults, isFalse);
  });
}
