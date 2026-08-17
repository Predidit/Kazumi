import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/info/info_header_slivers.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/repositories/collect_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final width in <double>[360, 600, 1200]) {
    for (final scale in <double>[1, 1.3, 1.5, 1.7, 2, 3]) {
      testWidgets(
        'keeps info and collect controls reachable at ${width}x ${scale}x',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          _bootstrapCollectController();

          await tester.pumpWidget(_cardApp(textScale: scale));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          final cardFinder = find.byType(BangumiInfoCardV);
          final cardRect = tester.getRect(cardFinder);
          final titleFinder = find.text(_longTitle);
          final dateFinder = find.text('2026-08-17');
          final scoreFinder = find.text('8.2');
          final buttonFinder = find.widgetWithText(FilledButton, '未追');

          for (final finder in [
            titleFinder,
            dateFinder,
            scoreFinder,
            buttonFinder,
          ]) {
            expect(finder, findsOneWidget);
            final rect = tester.getRect(finder);
            expect(rect.top, greaterThanOrEqualTo(cardRect.top));
            expect(rect.bottom, lessThanOrEqualTo(cardRect.bottom));
            expect(rect.left, greaterThanOrEqualTo(cardRect.left));
            expect(rect.right, lessThanOrEqualTo(cardRect.right));
          }
          if (width == 1200 && scale == 1) {
            expect(find.text('  评分透视:'), findsOneWidget);
          }
          if (width == 1200 && scale == 1) {
            expect(find.text('  评分透视:'), findsOneWidget);
          }

          await tester.ensureVisible(buttonFinder);
          await tester.tap(buttonFinder);
          await tester.pumpAndSettle();

          expect(find.byType(MenuItemButton), findsNWidgets(6));
          final menuContext = tester.element(find.text(' 在看'));
          expect(
            MediaQuery.textScalerOf(menuContext).scale(16),
            closeTo(scale * 16, 0.01),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('card height grows with accessible text', (tester) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _bootstrapCollectController();

    await tester.pumpWidget(_cardApp(textScale: 1));
    await tester.pumpAndSettle();
    final normalHeight = tester.getSize(find.byType(BangumiInfoCardV)).height;

    await tester.pumpWidget(_cardApp(textScale: 3));
    await tester.pumpAndSettle();
    final accessibleHeight =
        tester.getSize(find.byType(BangumiInfoCardV)).height;

    expect(accessibleHeight, greaterThan(normalHeight));
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading card also keeps natural height at 3x', (tester) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _bootstrapCollectController();

    await tester.pumpWidget(_cardApp(textScale: 3, isLoading: true));
    await tester.pump();

    expect(
        tester.getSize(find.byType(BangumiInfoCardV)).height, greaterThan(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('natural header scrolls away while the tab bar stays pinned',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _bootstrapCollectController();
    const headerKey = ValueKey('natural-info-header');

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 1000),
            textScaler: TextScaler.linear(3),
          ),
          child: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                title: const Text(
                  _longTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              body: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return buildInfoHeaderSlivers(
                    context: context,
                    tabBarColor: Theme.of(context).scaffoldBackgroundColor,
                    header: Container(
                      key: headerKey,
                      padding: const EdgeInsets.all(16),
                      child: BangumiInfoCardV(
                        bangumiItem: _bangumiItem(),
                        isLoading: false,
                        showRating: true,
                      ),
                    ),
                    tabBar: const TabBar(
                      tabs: [Tab(text: '概览'), Tab(text: '评论')],
                    ),
                  );
                },
                body: TabBarView(
                  children: [
                    _tabBody(const ValueKey('overview-body')),
                    _tabBody(const ValueKey('comments-body')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(headerKey), findsOneWidget);
    await tester.flingFrom(
      const Offset(180, 800),
      const Offset(0, -900),
      3000,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(headerKey), findsNothing);
    expect(
        tester.getTopLeft(find.byType(TabBar)).dy, closeTo(kToolbarHeight, 1));
    await tester.tap(find.text('评论'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('comments-body')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _tabBody(Key key) {
  return Builder(
    builder: (context) {
      return CustomScrollView(
        key: key,
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 1200)),
        ],
      );
    },
  );
}

const _longTitle = '这是一个非常非常长而且必须占据多行显示空间的番剧标题名称';

Widget _cardApp({required double textScale, bool isLoading = false}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BangumiInfoCardV(
                  bangumiItem: _bangumiItem(),
                  isLoading: isLoading,
                  showRating: true,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

BangumiItem _bangumiItem() {
  return BangumiItem(
    id: 942,
    type: 2,
    name: _longTitle,
    nameCn: _longTitle,
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

void _bootstrapCollectController() {
  bootstrapModule(
    createModule(
      register: (context) => context.addInstance<CollectController>(
        CollectController(
          _FakeCollectCrudRepository(),
          _FakeCollectRepository(),
        ),
      ),
    ),
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
