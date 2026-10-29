import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/pages/onboarding/steps/plugin_shop_step.dart';
import 'package:kazumi/pages/plugin_editor/plugin_catalog_view.dart';
import 'package:kazumi/pages/plugin_editor/plugin_view_page.dart';
import 'package:kazumi/pages/plugin_editor/plugin_shop_page.dart';
import 'package:kazumi/pages/plugin_editor/rule_management_widgets.dart';
import 'package:kazumi/modules/plugin/plugin_http_module.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

PluginHTTPItem _item(String name) => PluginHTTPItem(
  name: name,
  version: '1.0',
  useNativePlayer: true,
  author: 'test',
  lastUpdate: 0,
);

Future<void> _mount(
  WidgetTester tester,
  Widget page, {
  TextScaler? textScaler,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: SettingsPaneScope(
        embedded: true,
        showBackButton: false,
        onBack: () {},
        child: Scaffold(body: page),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectMatchingActionHeights(WidgetTester tester) {
  final install = tester.getRect(
    find.descendant(
      of: find.byType(DownloadAllRulesButton),
      matching: find.byType(Material),
    ),
  );
  final refresh = tester.getRect(
    find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == '刷新规则列表',
      ),
      matching: find.byType(Material),
    ),
  );
  expect(refresh.height, closeTo(install.height, 0.1));
}

void main() {
  late Directory directory;
  late PathProviderPlatform originalPaths;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kazumi_rule_widget_');
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

  testWidgets('onboarding downloads all rules and disables duplicate clicks', (
    tester,
  ) async {
    final release = Completer<void>();
    var downloads = 0;
    final controller = PluginsController(
      catalogLoader: () async => [_item('one'), _item('two')],
      pluginLoader: (name) async {
        downloads++;
        await release.future;
        return Plugin.fromTemplate()
          ..name = name
          ..version = '1.0';
      },
      pluginJsonWriter: (_) async {},
    );
    await _mount(tester, PluginShopStep(controller: controller));
    _expectMatchingActionHeights(tester);

    await tester.tap(find.text('安装全部规则'));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.descendant(
        of: find.byType(DownloadAllRulesButton),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.text('正在安装规则'), findsWidgets);
    expect(downloads, 2);
    _expectMatchingActionHeights(tester);

    release.complete();
    await tester.pumpAndSettle();

    expect(controller.pluginList, hasLength(2));
    expect(find.text('规则仓库 · 已安装 2'), findsOneWidget);
    expect(find.text('安装成功 2 条'), findsOneWidget);
    expect(find.text('已安装'), findsNWidgets(2));
    expect(find.byType(DownloadAllRulesButton), findsOneWidget);
    expect(find.byTooltip('刷新规则列表'), findsOneWidget);
  });

  testWidgets('catalog installs all rules despite the current search', (
    tester,
  ) async {
    final controller = PluginsController(
      catalogLoader: () async => [_item('one'), _item('two')],
      pluginLoader: (name) async => Plugin.fromTemplate()
        ..name = name
        ..version = '1.0',
      pluginJsonWriter: (_) async {},
    );
    await _mount(tester, PluginShopPage(controller: controller));
    await tester.enterText(find.byType(TextField), 'one');
    await tester.tap(find.text('安装全部规则'));
    await tester.pumpAndSettle();

    expect(controller.pluginList, hasLength(2));
    expect(find.text('全部 2'), findsOneWidget);
    expect(find.text('安装成功 2 条'), findsOneWidget);

    await tester.tap(find.text('安装全部规则'));
    await tester.pumpAndSettle();
    expect(find.text('所有规则均已安装且为最新'), findsOneWidget);
  });

  testWidgets('catalog retries installation after a load error', (
    tester,
  ) async {
    var offline = true;
    final controller = PluginsController(
      catalogLoader: () async {
        if (offline) throw StateError('offline');
        return [_item('one')];
      },
      pluginLoader: (name) async => Plugin.fromTemplate()
        ..name = name
        ..version = '1.0',
      pluginJsonWriter: (_) async {},
      errorReporter: (_, _, _) {},
    );
    await _mount(tester, PluginShopPage(controller: controller));
    expect(find.text('无法访问规则仓库'), findsOneWidget);

    offline = false;
    await tester.ensureVisible(find.text('重新加载'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('安装全部规则'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('安装全部规则'));
    await tester.pumpAndSettle();

    expect(controller.pluginList.single.name, 'one');
    expect(find.text('安装成功 1 条'), findsOneWidget);
  });

  testWidgets('catalog disables downloads while loading and when empty', (
    tester,
  ) async {
    final catalog = Completer<List<PluginHTTPItem>>();
    final controller = PluginsController(catalogLoader: () => catalog.future);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PluginCatalogView(controller: controller)),
      ),
    );
    await tester.pump();
    FilledButton button() => tester.widget<FilledButton>(
      find.descendant(
        of: find.byType(DownloadAllRulesButton),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button().onPressed, isNull);

    catalog.complete([]);
    await tester.pumpAndSettle();
    expect(button().onPressed, isNull);
  });

  for (final onboarding in [true, false]) {
    for (final scale in [2.5, 3.0]) {
      testWidgets(
        '${onboarding ? 'onboarding' : 'catalog'} actions fit large text at $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final download = Completer<Plugin>();
          final controller = PluginsController(
            catalogLoader: () async => [_item('one')],
            pluginLoader: (_) => download.future,
            pluginJsonWriter: (_) async {},
          );
          await _mount(
            tester,
            onboarding
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: PluginShopStep(controller: controller),
                  )
                : PluginShopPage(controller: controller),
            textScaler: TextScaler.linear(scale),
          );

          final install = find.byType(DownloadAllRulesButton);
          final refresh = find.byTooltip('刷新规则列表');
          void expectActionsFit() {
            for (final action in [install, refresh]) {
              final bounds = tester.getRect(action);
              expect(bounds.left, greaterThanOrEqualTo(onboarding ? 20 : 16));
              expect(bounds.right, lessThanOrEqualTo(onboarding ? 300 : 304));
            }
            _expectMatchingActionHeights(tester);
            expect(tester.takeException(), isNull);
          }

          expectActionsFit();
          await tester.ensureVisible(install);
          await tester.pumpAndSettle();
          await tester.tap(install);
          await tester.pump();
          expect(find.text('正在安装规则'), findsWidgets);
          expectActionsFit();

          download.complete(
            Plugin.fromTemplate()
              ..name = 'one'
              ..version = '1.0',
          );
          await tester.pumpAndSettle();
          expect(install, findsOneWidget);
          expect(refresh, findsOneWidget);
        },
      );
    }
  }

  testWidgets('narrow install buttons constrain both labels', (tester) async {
    for (final downloading in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 160,
                  child: DownloadAllRulesButton(
                    downloading: downloading,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final button = tester.getRect(find.byType(DownloadAllRulesButton));
      final label = tester.getRect(
        find.text(downloading ? '正在安装规则' : '安装全部规则'),
      );
      expect(label.left, greaterThanOrEqualTo(button.left));
      expect(label.right, lessThanOrEqualTo(button.right));
      expect(tester.takeException(), isNull);
    }
  });

  for (final width in [320.0, 1280.0]) {
    testWidgets('download actions fit a $width wide screen', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PluginsController(
        catalogLoader: () async => [_item('one')],
      );

      await _mount(tester, PluginShopStep(controller: controller));
      expect(find.text('安装全部规则'), findsOneWidget);
      _expectMatchingActionHeights(tester);
      expect(tester.takeException(), isNull);

      await _mount(tester, PluginViewPage(controller: controller));
      expect(find.text('安装全部规则'), findsNothing);
      expect(find.text('规则仓库'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _mount(tester, PluginShopPage(controller: controller));
      expect(find.text('安装全部规则'), findsOneWidget);
      _expectMatchingActionHeights(tester);
      final install = tester.getRect(find.byType(DownloadAllRulesButton));
      final refresh = tester.getRect(find.byTooltip('刷新规则列表'));
      final sort = tester.getRect(find.text('最近更新'));
      expect(install.right, lessThan(refresh.left));
      expect(install.center.dy, closeTo(refresh.center.dy, 0.1));
      expect(install.center.dy, closeTo(sort.center.dy, 0.1));
      expect(tester.takeException(), isNull);
    });
  }
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String> getApplicationSupportPath() async => path;
}
