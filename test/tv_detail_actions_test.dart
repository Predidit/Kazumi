import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/info/tv_detail_actions.dart';
import 'package:kazumi/services/platform/tv_mode.dart';

class _ReadOnlyCollectController implements CollectController {
  @override
  int getCollectType(BangumiItem item) => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BangumiItem _item() => BangumiItem(
      id: 1,
      type: 2,
      name: 'A long anime title that remains readable beside the poster',
      nameCn: '',
      summary: '',
      airDate: '2026-09-05',
      airWeekday: 6,
      rank: 123,
      images: {},
      tags: [],
      alias: [],
      ratingScore: 8.1,
      votes: 1000,
      votesCount: List.filled(10, 100),
      info: '',
    );

Widget _collection(FocusNode node) => FilledButton.icon(
      focusNode: node,
      onPressed: () {},
      icon: const Icon(Icons.favorite_border),
      label: const Text('未追'),
    );

void main() {
  setUp(() {
    bootstrapModule(createModule(register: (c) {
      c.addInstance<CollectController>(_ReadOnlyCollectController());
    }));
  });
  tearDown(() => TvMode.setEnabledForTesting(false));

  testWidgets('real TV collection owns arrows and native navigator back',
      (tester) async {
    TvMode.setEnabledForTesting(true);
    final play = FocusNode();
    addTearDown(play.dispose);
    final navigator = GlobalKey<NavigatorState>();
    var down = 0;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      home: const Scaffold(body: Text('home')),
    ));
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        body: TvDetailActions(
          playFocus: play,
          onPlay: () {},
          collectionBuilder: (node) =>
              CollectButton.extend(bangumiItem: _item(), focusNode: node),
          onReview: () {},
          onUp: () {},
          onDown: () => down++,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    final collectionFocus = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, isNot(same(collectionFocus)));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(down, 0);
    // TV native channel calls maybePop, not Flutter's Escape shortcut.
    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(find.text('开始观看'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, same(collectionFocus));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(play.hasPrimaryFocus, isTrue);
    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile info card retains its original collection-only layout',
      (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final item = _item()..name = 'Mobile title';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: BangumiInfoCardV(
          bangumiItem: item, isLoading: false, showRating: true),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(TvDetailActions), findsNothing);
    expect(find.byType(CollectButton), findsOneWidget);
    expect(tester.getRect(find.text('Mobile title')).bottom,
        lessThan(tester.getRect(find.byType(NetworkImgLayer)).top));
    expect(tester.takeException(), isNull);
  });

  for (final width in [854.0, 960.0, 1280.0]) {
    testWidgets('TV header at $width puts focused watch beside poster',
        (tester) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final playFocus = FocusNode();
      addTearDown(playFocus.dispose);
      var plays = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: BangumiInfoCardV(
              bangumiItem: _item(),
              isLoading: false,
              showRating: true,
              tvActions: TvDetailActions(
                playFocus: playFocus,
                onPlay: () => plays++,
                collectionBuilder: _collection,
                onReview: () {},
                onUp: () {},
                onDown: () {},
              ),
            ),
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(width == 960 ? 1.25 : 1)),
          child: child!,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final poster = tester.getRect(find.byType(NetworkImgLayer));
      final play = tester.getRect(find.widgetWithText(FilledButton, '开始观看'));
      final title = tester.getRect(find.text(_item().name));
      expect(play.left, greaterThan(poster.right));
      expect(play.top, greaterThan(title.bottom));
      expect(play.bottom, lessThan(poster.bottom));
      expect(playFocus.hasPrimaryFocus, isTrue);
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(plays, 1);
    });
  }

  testWidgets('actions cycle both edges, expose vertical exits and review',
      (tester) async {
    final play = FocusNode();
    addTearDown(play.dispose);
    var up = 0;
    var down = 0;
    var reviews = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: TvDetailActions(
        playFocus: play,
        onPlay: () {},
        collectionBuilder: _collection,
        onReview: () => reviews++,
        onUp: () => up++,
        onDown: () => down++,
      ),
    )));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(reviews, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(play.hasPrimaryFocus, isTrue);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
    }
    expect(play.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(up, 1);
    expect(down, 1);
  });

  testWidgets('collection menu owns its arrows and returns focus on cancel',
      (tester) async {
    final play = FocusNode();
    addTearDown(play.dispose);
    FocusNode? collection;
    var down = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: TvDetailActions(
        playFocus: play,
        onPlay: () {},
        collectionBuilder: (node) {
          collection = node;
          return MenuAnchor(
            childFocusNode: node,
            menuChildren: [
              MenuItemButton(onPressed: () {}, child: const Text('在看')),
              MenuItemButton(onPressed: () {}, child: const Text('想看')),
            ],
            builder: (_, controller, child) => FilledButton(
              focusNode: node,
              onPressed: controller.open,
              child: const Text('未追'),
            ),
          );
        },
        onReview: () {},
        onUp: () {},
        onDown: () => down++,
      ),
    )));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(collection!.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('在看'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(down, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('在看'), findsNothing);
    expect(collection!.hasPrimaryFocus, isTrue);
  });

  testWidgets('loading refresh does not steal action focus or hide playback',
      (tester) async {
    final play = FocusNode();
    addTearDown(play.dispose);
    late StateSetter rebuild;
    var loading = true;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: StatefulBuilder(builder: (context, setState) {
        rebuild = setState;
        return BangumiInfoCardV(
          bangumiItem: _item(),
          isLoading: loading,
          showRating: false,
          tvActions: TvDetailActions(
            playFocus: play,
            onPlay: () {},
            collectionBuilder: _collection,
            onReview: () {},
            onUp: () {},
            onDown: () {},
          ),
        );
      }),
    )));
    await tester.pump(const Duration(milliseconds: 100));
    expect(play.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final before = FocusManager.instance.primaryFocus;
    rebuild(() => loading = false);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(before));
    expect(find.text('开始观看'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
