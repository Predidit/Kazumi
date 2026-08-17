import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/repositories/collect_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final scale in <double>[1, 1.5, 2]) {
    testWidgets(
      'keeps the collect button visible and tappable at ${scale}x text',
      (tester) async {
        _bootstrapCollectController();
        await tester.pumpWidget(_testApp(textScale: scale));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final cardRect = tester.getRect(find.byType(BangumiInfoCardV));
        final buttonFinder = find.widgetWithText(FilledButton, '未追');
        expect(buttonFinder, findsOneWidget);
        final buttonRect = tester.getRect(buttonFinder);
        expect(cardRect.contains(buttonRect.topLeft), isTrue);
        expect(buttonRect.right, lessThanOrEqualTo(cardRect.right));
        expect(buttonRect.bottom, lessThanOrEqualTo(cardRect.bottom));

        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        expect(find.byType(MenuItemButton), findsNWidgets(6));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('keeps the extended collect button on wide normal text',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _bootstrapCollectController();
    await tester.pumpWidget(_testApp(textScale: 1, width: 1200));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '未追'), findsOneWidget);
    expect(find.text('  评分透视:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not consume the outer header drag', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _bootstrapCollectController();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: NestedScrollView(
              controller: scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  expandedHeight: 340,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Padding(
                      padding: const EdgeInsets.only(top: kToolbarHeight),
                      child: BangumiInfoCardV(
                        bangumiItem: _longTitleBangumi(),
                        isLoading: false,
                        showRating: true,
                      ),
                    ),
                  ),
                ),
              ],
              body: ListView(
                children: const [SizedBox(height: 1200)],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(BangumiInfoCardV),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              (widget.axisDirection == AxisDirection.up ||
                  widget.axisDirection == AxisDirection.down),
        ),
      ),
      findsNothing,
    );
    await tester.dragFrom(const Offset(270, 240), const Offset(0, -160));
    await tester.pumpAndSettle();

    expect(scrollController.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}

void _bootstrapCollectController() {
  final collectController = CollectController(
    _FakeCollectCrudRepository(),
    _FakeCollectRepository(),
  );
  bootstrapModule(
    createModule(
      register: (context) =>
          context.addInstance<CollectController>(collectController),
    ),
  );
}

Widget _testApp({required double textScale, double width = 360}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: BangumiInfoCardV(
              bangumiItem: _longTitleBangumi(),
              isLoading: false,
              showRating: true,
            ),
          ),
        ),
      ),
    ),
  );
}

BangumiItem _longTitleBangumi() {
  return BangumiItem(
    id: 942,
    type: 2,
    name: 'A Very Long Anime Title That Must Wrap Across Multiple Lines',
    nameCn: '这是一个非常非常长而且必须占据两行显示空间的番剧标题名称',
    summary: 'summary',
    airDate: '2026-08-17',
    airWeekday: 1,
    rank: 942,
    images: const <String, String>{},
    tags: const [],
    alias: const [],
    ratingScore: 8.2,
    votes: 1000,
    votesCount: List<int>.filled(10, 100),
    info: '',
  );
}

class _FakeCollectCrudRepository implements ICollectCrudRepository {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<void> addCollectChange(CollectedBangumiChange change) async {}

  @override
  Future<void> addCollectible(BangumiItem bangumiItem, int type) async {}

  @override
  Future<void> clearFavorites() async {}

  @override
  Future<void> deleteCollectible(int id) async {}

  @override
  List<CollectedBangumi> getAllCollectibles() => const [];

  @override
  CollectedBangumi? getCollectible(int id) => null;

  @override
  int getCollectType(int id) => 0;

  @override
  List<BangumiItem> getFavorites() => const [];

  @override
  Future<void> updateCollectible(BangumiItem bangumiItem) async {}
}

class _FakeCollectRepository implements ICollectRepository {
  @override
  Set<int> getBangumiIdsByType(CollectType type) => const {};

  @override
  Set<int> getBangumiIdsByTypes(List<CollectType> types) => const {};

  @override
  bool getPrivateMode() => false;

  @override
  bool getTimelineNotShowAbandonedBangumis() => false;

  @override
  bool getTimelineNotShowWatchedBangumis() => false;

  @override
  bool getTimelineOnlyShowWatchingBangumis() => false;

  @override
  Future<void> updateTimelineNotShowAbandonedBangumis(bool value) async {}

  @override
  Future<void> updateTimelineNotShowWatchedBangumis(bool value) async {}

  @override
  Future<void> updateTimelineOnlyShowWatchingBangumis(bool value) async {}
}
