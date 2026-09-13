import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:kazumi/bean/widget/tv_focusable_surface.dart';
import 'package:kazumi/bean/widget/episode_tile.dart';
import 'package:kazumi/bean/widget/tv_focus_navigation.dart';
import 'package:kazumi/pages/history/history_page.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/bean/card/bangumi_history_card.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/pages/popular/popular_page.dart';
import 'package:kazumi/pages/search/search_page.dart';
import 'package:kazumi/services/platform/tv_mode.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/navigation.dart';
import 'support/tv_focus_fixtures.dart';

class _TempPaths extends PathProviderPlatform {
  _TempPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump(const Duration(milliseconds: 400));
}

FocusNode nodeForSurface(WidgetTester tester, Finder finder) =>
    tester.widget<TvFocusableSurface>(finder).focusNode!;
FocusNode channel(WidgetTester tester, int number) => tester
    .widget<BangumiCardV>(find.byWidgetPredicate(
        (w) => w is BangumiCardV && w.channelNumber == number))
    .focusNode!;

void main() {
  late Directory temp;
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('kazumi_focus_regression_');
    PathProviderPlatform.instance = _TempPaths(temp.path);
    Hive.init(temp.path);
    await GStorage.init();
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });
  setUp(() {
    TvMode.setEnabledForTesting(true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.predidit.kazumi/tv_navigation'),
            (_) async => null);
  });
  tearDown(() => TvMode.setEnabledForTesting(false));

  Future<void> mount(WidgetTester tester, FocusFixtureApp app) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  testWidgets('search distinguishes empty, failure and partial page failure',
      (tester) async {
    final app = FocusFixtureApp(initialRoute: '/search/');
    app.search.preserveResults = true;
    app.search.isTimeOut = true;
    await mount(tester, app);
    await press(tester, LogicalKeyboardKey.select);
    await tester.enterText(find.byKey(const Key('tv-search-editor')), 'test');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('搜索请求失败'), findsOneWidget);
    expect(find.text('没有找到番剧'), findsNothing);
    app.search.hasMoreSearchResults = false;
    app.search.isTimeOut = false;
    await tester.pump();
    expect(find.text('没有找到番剧'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
    app.search.bangumiList.add(focusItem(99));
    app.search.isTimeOut = true;
    await tester.pump();
    expect(find.text(focusItem(99).nameCn), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('加载失败，重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cold TV shell gives OK an actionable search focus',
      (tester) async {
    await mount(tester, FocusFixtureApp());
    final search = tester.widget<FloatingActionButton>(
        find.widgetWithIcon(FloatingActionButton, Icons.search));
    expect(search.focusNode!.hasPrimaryFocus, isTrue,
        reason: 'Actual focus: ${FocusManager.instance.primaryFocus}');
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse,
        reason: 'Entering search must not implicitly open the keyboard');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'cold history RIGHT enters an actionable control, never an empty route scope',
      (tester) async {
    await mount(tester, FocusFixtureApp(initialRoute: '/tab/history/'));
    await press(tester, LogicalKeyboardKey.arrowRight);
    final focus = FocusManager.instance.primaryFocus;
    expect(focus, isNot(isA<FocusScopeNode>()));
    expect(focus?.ancestors.any((node) => node.debugLabel == 'TV content'),
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UI01 real shell: first column LEFT returns rail, RIGHT restores card and category',
      (tester) async {
    final app = FocusFixtureApp();
    await mount(tester, app);
    channel(tester, 1).requestFocus();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(
        FocusManager.instance.primaryFocus!.ancestors
            .any((n) => n.debugLabel == 'TV navigation rail'),
        isTrue);
    expect(app.popular.currentTag, '');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(channel(tester, 1).hasPrimaryFocus, isTrue);
    expect(app.popular.currentTag, '');
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(FocusManager.instance.primaryFocus!.debugLabel, 'TV category 热门番组');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(channel(tester, 1).hasPrimaryFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UI01 real shell restores card and scroll after a detail route',
      (tester) async {
    final app = FocusFixtureApp();
    await mount(tester, app);
    channel(tester, 1).requestFocus();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowDown);
    final before = FocusManager.instance.primaryFocus;
    final popular = tester.state(find.byType(PopularPage));
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('详情路由：本地测试'), findsOneWidget);
    await rootNavigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(PopularPage)), same(popular));
    expect(FocusManager.instance.primaryFocus, same(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('UI01 one item retains category and rail exits', (tester) async {
    await mount(tester, FocusFixtureApp(count: 1));
    channel(tester, 1).requestFocus();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(channel(tester, 1).hasPrimaryFocus, isTrue);
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(
        FocusManager.instance.primaryFocus!.ancestors
            .any((n) => n.debugLabel == 'TV navigation rail'),
        isTrue);
  });

  testWidgets(
      'UI03 actual search page: arrows do not show IME, OK edits, native back restores entry',
      (tester) async {
    final app = FocusFixtureApp(initialRoute: '/search/');
    await mount(tester, app);
    expect(find.byType(SearchPage), findsOneWidget);
    final entry =
        nodeForSurface(tester, find.byKey(const Key('tv-search-entry')));
    expect(entry.hasPrimaryFocus, isTrue);
    expect(tester.testTextInput.isVisible, isFalse);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(tester.testTextInput.isVisible, isFalse);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(entry.hasPrimaryFocus, isTrue);
    await press(tester, LogicalKeyboardKey.select);
    expect(find.byKey(const Key('tv-search-editor')), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);
    await rootNavigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tv-search-editor')), findsNothing);
    expect(entry.hasPrimaryFocus, isTrue);
    expect(app.search.submitted, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UI03 submit uses real search controller path without attached SearchAnchor',
      (tester) async {
    final app = FocusFixtureApp(initialRoute: '/search/');
    await mount(tester, app);
    await press(tester, LogicalKeyboardKey.select);
    await tester.enterText(
        find.byKey(const Key('tv-search-editor')), 'test anime');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(app.search.submitted, 'test anime');
    expect(find.byKey(const Key('tv-search-editor')), findsNothing);
    expect(
        nodeForSurface(tester, find.byKey(const Key('tv-search-entry')))
            .hasPrimaryFocus,
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UI04 actual history: more and collection menus close one layer at a time',
      (tester) async {
    await mount(tester, FocusFixtureApp(initialRoute: '/tab/history/'));
    final card = tester
        .widget<BangumiHistoryCardV>(find.byType(BangumiHistoryCardV).first);
    card.focusNode!.requestFocus();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowRight);
    final more = FocusManager.instance.primaryFocus;
    await press(tester, LogicalKeyboardKey.select);
    expect(find.text('历史操作'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    expect(find.byType(MenuItemButton), findsNWidgets(6));
    await rootNavigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(find.text('历史操作'), findsOneWidget);
    expect(
        tester
            .widget<CollectButton>(find.byType(CollectButton))
            .focusNode!
            .hasPrimaryFocus,
        isTrue);
    await rootNavigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('历史操作'), findsNothing);
    expect(FocusManager.instance.primaryFocus, same(more));
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(card.focusNode!.hasPrimaryFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UI04 delete cancel is safe, confirm deletes only target and restores next, then empty exit',
      (tester) async {
    final app = FocusFixtureApp(initialRoute: '/tab/history/', historyCount: 1);
    await mount(tester, app);
    var card = tester
        .widget<BangumiHistoryCardV>(find.byType(BangumiHistoryCardV).first);
    await tester.tap(find.byTooltip('管理历史记录'));
    await tester.pump();
    card = tester
        .widget<BangumiHistoryCardV>(find.byType(BangumiHistoryCardV).first);
    card.focusNode!.requestFocus();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.select);
    expect(find.text('删除记录'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.select); // default is Cancel
    expect(app.historyRepository.deleted, isEmpty);
    expect(card.focusNode!.hasPrimaryFocus, isTrue);
    await press(tester, LogicalKeyboardKey.select);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(app.historyRepository.deleted, [card.historyItem.key]);
    expect(find.text('暂无历史记录'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus!.debugLabel,
        'TV empty history back');
    await press(tester, LogicalKeyboardKey.select);
    expect(
        FocusManager.instance.primaryFocus!.ancestors
            .any((n) => n.debugLabel == 'TV navigation rail'),
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UI04 card OK still invokes resume with the same history',
      (tester) async {
    final app = FocusFixtureApp(initialRoute: '/tab/history/');
    await mount(tester, app);
    final card = tester
        .widget<BangumiHistoryCardV>(find.byType(BangumiHistoryCardV).first);
    card.focusNode!.requestFocus();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.select);
    expect(app.playback.opened, [same(card.historyItem)]);
    await tester.pumpAndSettle();
    expect(find.text('续播路由：仅验证参数，不是真实视频'), findsOneWidget);
    await rootNavigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(card.focusNode!.hasPrimaryFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UI01 ragged last row wraps and rail round-trip preserves scrolled position',
      (tester) async {
    final app = FocusFixtureApp(count: 31);
    await mount(tester, app);
    final grid = tester.widget<SliverGrid>(find.descendant(
        of: find.byType(PopularPage), matching: find.byType(SliverGrid)));
    final columns =
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount;
    channel(tester, 1).requestFocus();
    await tester.pump();
    for (var i = 0; i < 30 ~/ columns; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    final number = 30 ~/ columns * columns + 1;
    expect(channel(tester, number).hasPrimaryFocus, isTrue);
    final offset = app.popular.scrollOffset;
    expect(offset, greaterThan(0));
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(channel(tester, number).hasPrimaryFocus, isTrue);
    expect(app.popular.scrollOffset, closeTo(offset, 1));
    await press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus!.debugLabel,
        startsWith('TV channel'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('UI01 empty category does not trap focus on DOWN',
      (tester) async {
    final app = FocusFixtureApp(count: 0);
    await mount(tester, app);
    final tab = tester.widget<TvFocusableSurface>(find.ancestor(
        of: find.text('热门番组'), matching: find.byType(TvFocusableSurface)));
    tab.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(tab.focusNode!.hasPrimaryFocus, isTrue);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(
        FocusManager.instance.primaryFocus!.ancestors
            .any((n) => n.debugLabel == 'TV navigation rail'),
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UI04 more menu delete restores the following record, not an invisible disposed node',
      (tester) async {
    final app = FocusFixtureApp(initialRoute: '/tab/history/', historyCount: 3);
    await mount(tester, app);
    final first = tester
        .widget<BangumiHistoryCardV>(find.byType(BangumiHistoryCardV).first);
    first.focusNode!.requestFocus();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.select);
    for (var i = 0; i < 3; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('只删除这条观看历史，不删除缓存或追番。'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(app.historyRepository.deleted, [first.historyItem.key]);
    final next = tester
        .widget<BangumiHistoryCardV>(find.byType(BangumiHistoryCardV).first);
    expect(next.historyItem.bangumiItem.id, 2);
    expect(next.focusNode!.hasPrimaryFocus, isTrue);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.select);
    expect(find.text('历史操作'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UI04 long history DOWN realizes offscreen cards and wraps only real items',
      (tester) async {
    final app =
        FocusFixtureApp(initialRoute: '/tab/history/', historyCount: 25);
    await mount(tester, app);
    final grid = tester.widget<SliverGrid>(find.descendant(
        of: find.byType(HistoryPage), matching: find.byType(SliverGrid)));
    final columns =
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount;
    final first = tester
        .widget<BangumiHistoryCardV>(find.byType(BangumiHistoryCardV).first);
    first.focusNode!.requestFocus();
    await tester.pump();
    var index = 0;
    for (var i = 0; i < 12; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      index = tvGridTarget(index, 25, columns, TraversalDirection.down);
      expect(FocusManager.instance.primaryFocus!.debugLabel,
          'TV history ${app.history.histories[index].key}');
    }
    expect(tester.takeException(), isNull);
  });

  Future<FocusNode?> pendingHistoryScroll(WidgetTester tester,
      {bool fromMore = false}) async {
    await mount(tester,
        FocusFixtureApp(initialRoute: '/tab/history/', historyCount: 25));
    tester
        .widget<BangumiHistoryCardV>(find.byType(BangumiHistoryCardV).first)
        .focusNode!
        .requestFocus();
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    if (fromMore) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    final origin = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 10));
    return origin;
  }

  testWidgets('UI04 pending DOWN cannot steal newer RIGHT More focus',
      (tester) async {
    await pendingHistoryScroll(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    final latest = FocusManager.instance.primaryFocus;
    expect(latest?.debugLabel, 'TV history more');
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(latest));
    expect(latest!.rect.top, greaterThanOrEqualTo(56));
    expect(latest.rect.bottom, lessThanOrEqualTo(540));
  });

  testWidgets('UI04 pending DOWN from More cannot steal newer local LEFT',
      (tester) async {
    await pendingHistoryScroll(tester, fromMore: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    final latest = FocusManager.instance.primaryFocus;
    expect(latest?.debugLabel, 'TV history 本地测试源5::online');
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(latest));
  });

  testWidgets('UI04 pending DOWN then LEFT retains rail focus', (tester) async {
    await pendingHistoryScroll(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    final latest = FocusManager.instance.primaryFocus;
    expect(latest!.ancestors.any((n) => n.debugLabel == 'TV navigation rail'),
        isTrue);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(latest));
  });

  testWidgets('UI04 pending DOWN then More menu and native BACK restores More',
      (tester) async {
    await pendingHistoryScroll(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    final more = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('历史操作'), findsOneWidget);
    await rootNavigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('历史操作'), findsNothing);
    expect(FocusManager.instance.primaryFocus, same(more));
    expect(tester.takeException(), isNull);
  });

  testWidgets('UI04 native BACK during pending DOWN leaves history safely',
      (tester) async {
    await pendingHistoryScroll(tester);
    await rootNavigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(HistoryPage), findsNothing);
    expect(find.byType(PopularPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UI04 repeated pending DOWN still realizes target',
      (tester) async {
    await pendingHistoryScroll(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 10));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel,
        'TV history 本地测试源7::online');
    expect(tester.takeException(), isNull);
  });

  testWidgets('UI03 mobile search keeps editable SearchBar', (tester) async {
    TvMode.setEnabledForTesting(false);
    await mount(tester, FocusFixtureApp(initialRoute: '/search/'));
    expect(find.byType(SearchBar), findsOneWidget);
    expect(tester.widget<SearchBar>(find.byType(SearchBar)).readOnly, isFalse);
    expect(find.byKey(const Key('tv-search-entry')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'mobile portrait search submits text and keeps results at large text scale',
      (tester) async {
    TvMode.setEnabledForTesting(false);
    final app = FocusFixtureApp(initialRoute: '/search/', textScale: 1.3);
    await mount(tester, app);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    final input = find.descendant(
        of: find.byType(SearchBar), matching: find.byType(TextField));
    await tester.enterText(input, 'phone query');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(app.search.submitted, 'phone query');
    expect(find.text(focusItem(99).nameCn), findsOneWidget);
    expect(find.byKey(const Key('tv-search-entry')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(854, 480), const Size(1280, 720)]) {
    testWidgets('UI04 history fits $size with 1.25 text scale', (tester) async {
      await mount(tester,
          FocusFixtureApp(initialRoute: '/tab/history/', textScale: 1.25));
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      final card = tester
          .widget<BangumiHistoryCardV>(find.byType(BangumiHistoryCardV).first);
      card.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.text('历史操作'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
        'UI02 actual episode tiles in $brightness have one focus frame, independent playing indicator',
        (tester) async {
      final nodes = [FocusNode(), FocusNode()];
      addTearDown(() {
        for (final n in nodes) {
          n.dispose();
        }
      });
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
              body: Row(children: [
            for (var i = 0; i < 2; i++)
              SizedBox(
                  width: 120,
                  height: 60,
                  child: EpisodeTile(
                      label: '第${i + 1}集',
                      isPlaying: i == 0,
                      focusNode: nodes[i],
                      onPressed: () {}))
          ]))));
      await tester.pump(const Duration(milliseconds: 200));
      nodes[1].requestFocus();
      await tester.pump(const Duration(milliseconds: 200));
      final frames = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .where((w) {
        final d = w.decoration;
        return d is BoxDecoration &&
            d.border is Border &&
            (d.border! as Border).top.color != Colors.transparent;
      });
      expect(frames.length, 1);
      expect(
          tester
              .widgetList<TvFocusableSurface>(find.byType(TvFocusableSurface))
              .every((s) => !s.highlighted),
          isTrue);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
      expect(nodes[1].hasPrimaryFocus, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}
