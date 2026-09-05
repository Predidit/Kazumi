import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/pages/collect/collect_library.dart';

BangumiItem _item(int id, String title) => BangumiItem(
      id: id,
      type: 2,
      name: 'Original $id',
      nameCn: title,
      summary: '',
      airDate: '',
      airWeekday: 1,
      rank: 0,
      images: {},
      tags: [],
      alias: ['Alias $id'],
      ratingScore: 0,
      votes: 0,
      votesCount: [],
      info: '',
    );

final _entries = [
  CollectedBangumi(_item(1, '葬送的芙莉莲'), DateTime(2026, 9, 3), 1),
  CollectedBangumi(_item(2, '迷宫饭'), DateTime(2026, 9, 4), 1),
  CollectedBangumi(_item(3, '夏目友人帐'), DateTime(2026, 9, 2), 2),
  CollectedBangumi(_item(4, '紫罗兰永恒花园'), DateTime(2026, 9, 1), 4),
  CollectedBangumi(_item(5, '跃动青春'), DateTime(2026, 8, 31), 1),
  CollectedBangumi(_item(6, '吹响！悠风号'), DateTime(2026, 8, 30), 1),
];

History _history(int entry, int day, {String source = '在线源'}) => History(
      _entries[entry].bangumiItem,
      7,
      source,
      DateTime(2026, 9, day),
      'https://example.com/anime',
      '',
    )..progresses[7] = Progress(7, 0, 754000);

const _previewKey = ValueKey('collect-preview');

Future<void> _pump(
  WidgetTester tester, {
  List<CollectedBangumi>? entries,
  List<History> histories = const [],
  Size size = const Size(1100, 1100),
  double scale = 1,
  bool managing = false,
  bool counts = true,
  bool dark = false,
  ValueChanged<History>? onResume,
  ValueChanged<BangumiItem>? onOpen,
  void Function(BangumiItem, CollectType)? onStatusChanged,
  VoidCallback? onDiscover,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff6750a4),
    brightness: dark ? Brightness.dark : Brightness.light,
  );
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(colorScheme: scheme, fontFamily: 'MiSansPreview'),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
      ),
      child: child!,
    ),
    home: RepaintBoundary(
      key: _previewKey,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 88,
          title: const Text('我的追番',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.sync_rounded)),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton.filledTonal(
                  onPressed: () {}, icon: const Icon(Icons.tune_rounded)),
            ),
          ],
        ),
        body: CollectLibrary(
          collectibles: entries ?? _entries,
          histories: histories,
          showCounts: counts,
          managing: managing,
          onOpen: onOpen ?? (_) {},
          onResume: onResume ?? (_) {},
          onStatusChanged: onStatusChanged ?? (_, __) {},
          onDiscover: onDiscover ?? () {},
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = FontLoader('MiSansPreview')
      ..addFont(rootBundle.load('assets/fonts/MiSans-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets(
      'filters by status and searches Chinese, original and alias names',
      (tester) async {
    await _pump(tester);
    expect(find.text('迷宫饭'), findsOneWidget);
    expect(find.text('夏目友人帐'), findsNothing);
    await tester.enterText(find.byType(TextField), 'alias 1');
    await tester.pumpAndSettle();
    expect(find.text('葬送的芙莉莲'), findsOneWidget);
    expect(find.text('迷宫饭'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Original 2');
    await tester.pumpAndSettle();
    expect(find.text('迷宫饭'), findsOneWidget);
    await tester.tap(find.byTooltip('清除搜索'));
    await tester.tap(find.text('想看'));
    await tester.pumpAndSettle();
    expect(find.text('夏目友人帐'), findsOneWidget);
    expect(find.text('迷宫饭'), findsNothing);
    await tester.enterText(find.byType(TextField), '不存在');
    await tester.pumpAndSettle();
    expect(find.text('没有找到匹配的番剧'), findsOneWidget);
    await tester.tap(find.text('清除搜索'));
    await tester.pumpAndSettle();
    expect(find.text('夏目友人帐'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resumes the latest source belonging to a watching collection',
      (tester) async {
    final old = _history(0, 1);
    final latest = _history(0, 4, source: '另一个源');
    final planned = _history(2, 5);
    History? resumed;
    await _pump(tester,
        histories: [old, planned, latest],
        onResume: (history) => resumed = history);
    expect(find.text('第 7 话 · 12:34'), findsOneWidget);
    await tester.tap(find.byTooltip('继续观看'));
    expect(resumed, same(latest));
    await tester.tap(find.text('想看'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('继续观看'), findsNothing);
  });

  testWidgets('sorts by watching time with unwatched entries last',
      (tester) async {
    await _pump(tester, histories: [_history(0, 4), _history(1, 2)]);
    await tester.tap(find.byTooltip('排序：最近收藏'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最近观看'));
    await tester.pumpAndSettle();
    final first = find.byKey(const ValueKey(1));
    final second = find.byKey(const ValueKey(2));
    expect(tester.getTopLeft(first).dx, lessThan(tester.getTopLeft(second).dx));
    expect(tester.getTopLeft(find.byKey(const ValueKey(5))).dy,
        greaterThan(tester.getTopLeft(first).dy));
  });

  testWidgets('normal tap opens details; management changes status or removes',
      (tester) async {
    BangumiItem? opened;
    CollectType? changed;
    await _pump(tester,
        onOpen: (item) => opened = item,
        onStatusChanged: (_, type) => changed = type);
    await tester.tap(find.text('迷宫饭'));
    expect(opened?.id, 2);
    await _pump(tester,
        managing: true,
        histories: [_history(1, 4)],
        onStatusChanged: (_, type) => changed = type);
    expect(find.byTooltip('继续观看'), findsNothing);
    await tester.tap(find.text('迷宫饭'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, '看过'));
    await tester.pumpAndSettle();
    expect(changed, CollectType.watched);
    await tester.tap(find.text('迷宫饭'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除收藏'));
    await tester.pumpAndSettle();
    expect(changed, CollectType.none);
  });

  testWidgets(
      'empty library can discover; empty category can switch to content',
      (tester) async {
    var discovered = false;
    await _pump(tester, entries: [], onDiscover: () => discovered = true);
    await tester.tap(find.text('发现番剧'));
    expect(discovered, isTrue);
    await _pump(tester, entries: [_entries[2]]);
    expect(find.text('还没有在看的番剧'), findsOneWidget);
    await tester.tap(find.text('查看想看'));
    await tester.pumpAndSettle();
    expect(find.text('夏目友人帐'), findsOneWidget);
  });

  for (final (label, size, scale, dark, counts) in [
    ('mobile', const Size(390, 844), 1.0, false, true),
    ('desktop', const Size(1440, 1000), 1.0, false, true),
    ('dark', const Size(390, 844), 1.0, true, true),
    ('large-text', const Size(320, 760), 2.0, false, false),
  ]) {
    testWidgets('$label layout stays usable and scrollable', (tester) async {
      await _pump(tester,
          size: size,
          scale: scale,
          dark: dark,
          counts: counts,
          histories: [_history(0, 4)]);
      expect(tester.takeException(), isNull);
      final output = Platform.environment['COLLECT_PREVIEW_DIR'];
      if (output != null) {
        await tester.runAsync(() async {
          final boundary = tester
              .renderObject<RenderRepaintBoundary>(find.byKey(_previewKey));
          final image = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File('$output/collect-$label.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey(6)),
        400,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey(6)), findsOneWidget);
    });
  }
}
