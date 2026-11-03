import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/core/acceleration_interceptors.dart';
import 'package:kazumi/services/network/rules_mirror.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform originalPaths;

  setUpAll(() async {
    Logger.level = Level.off;
    directory = await Directory.systemTemp.createTemp('kazumi_rules_mirror_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
    Hive.init(directory.path);
    await GStorage.init();
  });

  tearDownAll(() async {
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    await directory.delete(recursive: true);
  });

  RequestOptions intercept(String url) {
    final options = RequestOptions(path: url);
    RulesMirrorInterceptor().onRequest(options, RequestInterceptorHandler());
    return options;
  }

  for (final mode in RulesMirror.values) {
    test(
      '${mode.name} applies only to official catalog and rule URLs',
      () async {
        await GStorage.putSetting(SettingsKeys.rulesMirror, mode.name);
        expect(RulesMirror.current, mode);
        for (final file in ['index.json', 'demo.json']) {
          final officialUrl = '${ApiEndpoints.pluginShop}$file';
          final expectedUrl = switch (mode) {
            RulesMirror.direct => officialUrl,
            RulesMirror.ghProxy => '${ApiEndpoints.ghProxyMirror}$officialUrl',
            RulesMirror.ghfast => '${ApiEndpoints.ghfastMirror}$officialUrl',
            RulesMirror.gitcode => '${ApiEndpoints.gitcodeMirror}$file',
          };
          expect(intercept(officialUrl).uri.toString(), expectedUrl);
          for (final repository in [
            'https://example.com/rules/',
            'https://raw.githubusercontent.com/example/KazumiRules/main/',
          ]) {
            final customUrl = '$repository$file';
            final request = intercept(customUrl);
            expect(request.uri.toString(), customUrl);
            expect(request.extra, isEmpty);
          }
        }
      },
    );
  }
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
