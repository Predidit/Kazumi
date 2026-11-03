import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/pages/plugin_editor/plugin_shop_page.dart';
import 'package:kazumi/modules/plugin/plugin_http_module.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform originalPaths;

  setUpAll(() async {
    Logger.level = Level.off;
    directory = await Directory.systemTemp.createTemp('kazumi_repository_ui_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
    Hive.init(directory.path);
    // Keep widget-test writes inside the fake clock without real disk I/O.
    await Hive.openBox<dynamic>('setting', bytes: Uint8List(0));
    await GStorage.init();
  });

  tearDownAll(() async {
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester,
    PluginsController controller, {
    bool settle = true,
  }) async {
    await GStorage.putSetting(SettingsKeys.ruleRepositoryUrl, '');
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [KazumiDialog.observer],
        home: SettingsPaneScope(
          embedded: true,
          showBackButton: false,
          onBack: () {},
          child: PluginShopPage(controller: controller),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('设置规则仓库'));
    await tester.pumpAndSettle();
  }

  testWidgets('cancel preserves repository and catalog; dialog can reopen', (
    tester,
  ) async {
    var loads = 0;
    final controller = PluginsController(
      catalogLoader: () async {
        loads++;
        return [];
      },
    );
    await mount(tester, controller);
    await openSettings(tester);
    await tester.enterText(
      find.byType(TextField).last,
      'https://example.com/rules',
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(GStorage.getSetting(SettingsKeys.ruleRepositoryUrl), '');
    expect(loads, 1);
    await openSettings(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'saving custom repository refreshes and hides official mirror action',
    (tester) async {
      final requested = <String>[];
      final controller = PluginsController(
        catalogLoader: () async {
          requested.add(GStorage.getSetting(SettingsKeys.ruleRepositoryUrl));
          throw const FormatException('unavailable');
        },
        errorReporter: (_, _, _) {},
      );
      await mount(tester, controller);
      expect(find.text('切换加速'), findsOneWidget);
      await openSettings(tester);
      await tester.enterText(
        find.byType(TextField).last,
        'https://example.com/rules/index.json',
      );
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(requested.last, 'https://example.com/rules/');
      expect(
        GStorage.getSetting(SettingsKeys.ruleRepositoryUrl),
        requested.last,
      );
      expect(find.text('切换加速'), findsNothing);
      expect(find.text('仓库地址已保存，但目录加载失败'), findsOneWidget);

      await openSettings(tester);
      await tester.tap(find.text('恢复官方仓库'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(requested.last, '');
      expect(find.text('切换加速'), findsOneWidget);
    },
  );

  testWidgets('successful switch normalizes URL and refreshes catalog', (
    tester,
  ) async {
    final requested = <String>[];
    final controller = PluginsController(
      catalogLoader: () async {
        requested.add(GStorage.getSetting(SettingsKeys.ruleRepositoryUrl));
        return [];
      },
    );
    await mount(tester, controller);
    await openSettings(tester);
    await tester.enterText(
      find.byType(TextField).last,
      'https://example.com/rules',
    );
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(requested, ['', 'https://example.com/rules/']);
    expect(controller.isPluginCatalogFresh, isTrue);
    expect(find.text('已切换规则仓库'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'switch during initial catalog load displays only new repository',
    (tester) async {
      final oldLoad = Completer<List<PluginHTTPItem>>();
      final newLoad = Completer<List<PluginHTTPItem>>();
      var loads = 0;
      final controller = PluginsController(
        catalogLoader: () {
          loads++;
          return loads == 1 ? oldLoad.future : newLoad.future;
        },
      );
      await mount(tester, controller, settle: false);
      await tester.tap(find.byTooltip('设置规则仓库'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        find.byType(TextField).last,
        'https://example.com/rules',
      );
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump();
      expect(loads, 2);
      oldLoad.complete([
        PluginHTTPItem(
          name: 'old rule',
          version: '1',
          useNativePlayer: false,
          author: 'old',
          lastUpdate: 0,
        ),
      ]);
      await tester.pump();
      expect(controller.pluginHTTPList, isEmpty);
      newLoad.complete([
        PluginHTTPItem(
          name: 'new rule',
          version: '1',
          useNativePlayer: false,
          author: 'new',
          lastUpdate: 0,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('old rule'), findsNothing);
      expect(find.text('new rule'), findsOneWidget);
      expect(find.text('已切换规则仓库'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid URL does not persist or reload catalog', (tester) async {
    var loads = 0;
    final controller = PluginsController(
      catalogLoader: () async {
        loads++;
        return [];
      },
    );
    await mount(tester, controller);
    await openSettings(tester);
    await tester.enterText(find.byType(TextField).last, 'file:///tmp/rules');
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(GStorage.getSetting(SettingsKeys.ruleRepositoryUrl), '');
    expect(loads, 1);
    expect(find.text('规则仓库地址必须是有效的 HTTP 或 HTTPS URL'), findsOneWidget);
  });
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
