import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/popular/popular_page.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/device.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _OfflineController extends PopularController {
  _OfflineController() {
    trendList.addAll(
      List.generate(
        24,
        (index) => BangumiItem(
          id: index + 1,
          type: 2,
          name: 'Story $index',
          nameCn: '一部标题比较长的测试番组 $index',
          summary: '这个故事有一段比较长的简介，用来检查横幅和卡片在小屏幕上的显示。',
          airDate: '2026-10-01',
          airWeekday: 4,
          rank: 1,
          images: {},
          tags: [],
          alias: [],
          ratingScore: 8.2,
          votes: 0,
          votesCount: [],
          info: '',
        ),
      ),
    );
  }

  @override
  Future<void> queryBangumiByTrend({String type = 'add'}) async {}

  @override
  Future<void> queryBangumiByTag({String type = 'add'}) async {
    bangumiList.clear();
    bangumiList.addAll(trendList);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform originalPaths;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kazumi_home_test_');
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
  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(1280, 850),
  ]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('home fits $size at text scale $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: PopularPage(controller: _OfflineController()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('今天想看什么？'), findsOneWidget);
        // Exercise the horizontal posters and the lazy grid below the fold.
        for (var i = 0; i < 5; i++) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -520),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('desktop window controls remain reachable after scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _OfflineController();
    await tester.pumpWidget(
      MaterialApp(home: PopularPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    final closeButton = find.byTooltip('关闭窗口');
    final initialPosition = tester.getTopLeft(closeButton);
    expect(closeButton.hitTestable(), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
      await tester.pumpAndSettle();
    }
    expect(controller.scrollOffset, greaterThan(600));
    expect(find.text('今天想看什么？').hitTestable(), findsNothing);
    expect(closeButton.hitTestable(), findsOneWidget);
    expect(find.byType(dtb.DragToMoveArea).hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(closeButton), initialPosition);
    expect(tester.takeException(), isNull);
  }, skip: !isDesktop());

  testWidgets('category selection displays the selected feed', (tester) async {
    final controller = _OfflineController();
    await tester.pumpWidget(
      MaterialApp(home: PopularPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('奇幻'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(controller.currentTag, '奇幻');
    expect(find.text('奇幻 · 精选'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first data load replaces the loading sliver safely', (
    tester,
  ) async {
    final controller = _OfflineController();
    final items = controller.trendList.toList();
    controller.trendList.clear();
    controller.isLoadingMore = true;
    await tester.pumpWidget(
      MaterialApp(home: PopularPage(controller: controller)),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    controller.trendList.addAll(items);
    controller.isLoadingMore = false;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('✦  本周焦点'), findsOneWidget);
  });

  test('late category results do not mix into the current feed', () async {
    final requests = <String, Completer<List<BangumiItem>>>{};
    final controller = PopularController.withTagLoader((tag, _) {
      final request = Completer<List<BangumiItem>>();
      requests[tag] = request;
      return request.future;
    });
    final items = _OfflineController().trendList;
    controller.setCurrentTag('奇幻');
    final first = controller.queryBangumiByTag(type: 'init');
    controller.setCurrentTag('恋爱');
    final second = controller.queryBangumiByTag(type: 'init');
    requests['奇幻']!.complete([items.first]);
    await first;
    expect(controller.bangumiList, isEmpty);
    expect(controller.isLoadingMore, isTrue);
    requests['恋爱']!.complete([items[1]]);
    await second;
    expect(controller.bangumiList.map((item) => item.id), [items[1].id]);
    expect(controller.isLoadingMore, isFalse);
    expect(controller.isTimeOut, isFalse);
  });

  testWidgets('network errors stay readable on the dark home surface', (
    tester,
  ) async {
    final controller = _OfflineController();
    controller.trendList.clear();
    controller.isTimeOut = true;
    await tester.pumpWidget(
      MaterialApp(home: PopularPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    final title = tester.widget<Text>(find.text('暂时无法加载番剧'));
    expect(title.style!.color!.computeLuminance(), greaterThan(.5));
    expect(find.text('重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('returning to recommendations invalidates a pending category', () async {
    final request = Completer<List<BangumiItem>>();
    final controller = PopularController.withTagLoader(
      (_, _) => request.future,
    );
    controller.setCurrentTag('奇幻');
    final pending = controller.queryBangumiByTag(type: 'init');
    controller.setCurrentTag('');
    request.complete([]);
    await pending;
    expect(controller.currentTag, isEmpty);
    expect(controller.isLoadingMore, isFalse);
    expect(controller.isTimeOut, isFalse);
  });
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}
