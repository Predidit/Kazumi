import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/search/search_result_grid.dart';

BangumiItem _item(int id) {
  return BangumiItem(
    id: id,
    type: 2,
    name: 'name-$id',
    nameCn: 'name-$id',
    summary: '',
    airDate: '',
    airWeekday: 0,
    rank: id,
    images: const {},
    tags: const [],
    alias: const [],
    ratingScore: 0,
    votes: 0,
    votesCount: const [],
    info: '',
  );
}

Widget _card(BuildContext context, BangumiItem item) {
  return ColoredBox(
    key: ValueKey(item.id),
    color: Colors.blueGrey,
    child: Center(child: Text('item-${item.id}')),
  );
}

void main() {
  testWidgets('renders items in the supplied order', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchResultGrid(
            items: [_item(1), _item(2), _item(3)],
            crossCount: 2,
            cardExtent: 100,
            itemBuilder: _card,
            scrollController: ScrollController(),
          ),
        ),
      ),
    );

    expect(find.text('item-1'), findsOneWidget);
    expect(find.text('item-2'), findsOneWidget);
    expect(find.text('item-3'), findsOneWidget);
  });

  testWidgets('refreshes card content when item ids stay unchanged',
      (tester) async {
    late StateSetter update;
    var items = [_item(1)];
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            home: Scaffold(
              body: SearchResultGrid(
                items: items,
                crossCount: 1,
                cardExtent: 100,
                itemBuilder: (context, item) => Text(item.nameCn),
                scrollController: scrollController,
              ),
            ),
          );
        },
      ),
    );

    final refreshedItem = _item(1)..nameCn = 'updated-name';
    update(() => items = [refreshedItem]);
    await tester.pump();

    expect(find.text('updated-name'), findsOneWidget);
  });

  testWidgets('animates removed cards before settling on the hidden list',
      (tester) async {
    late StateSetter update;
    var items = [_item(1), _item(2), _item(3), _item(4)];
    final scrollController = ScrollController();
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 250,
                child: SearchResultGrid(
                  items: items,
                  crossCount: 2,
                  cardExtent: 100,
                  itemBuilder: _card,
                  scrollController: scrollController,
                ),
              ),
            ),
          );
        },
      ),
    );

    final initialPosition = tester.getTopLeft(find.text('item-3'));
    update(() => items = [_item(1), _item(3)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));

    expect(find.text('item-2'), findsOneWidget);
    final middlePosition = tester.getTopLeft(find.text('item-3'));
    await tester.pumpAndSettle();

    final finalPosition = tester.getTopLeft(find.text('item-3'));
    expect(middlePosition.dy, lessThan(initialPosition.dy));
    expect(middlePosition.dy, greaterThan(finalPosition.dy));
    expect(find.text('item-2'), findsNothing);
    expect(find.text('item-3'), findsOneWidget);
  });

  testWidgets('reverses an in-progress view transition without snapping',
      (tester) async {
    late StateSetter update;
    var items = [_item(1), _item(2), _item(3), _item(4)];
    final scrollController = ScrollController();
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 250,
                child: SearchResultGrid(
                  items: items,
                  crossCount: 2,
                  cardExtent: 100,
                  itemBuilder: _card,
                  scrollController: scrollController,
                ),
              ),
            ),
          );
        },
      ),
    );

    final initialPosition = tester.getTopLeft(find.text('item-3'));
    update(() => items = [_item(1), _item(3)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));
    final hiddenPosition = tester.getTopLeft(find.text('item-3'));

    update(() => items = [_item(1), _item(2), _item(3), _item(4)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 105));
    final returningPosition = tester.getTopLeft(find.text('item-3'));

    expect(returningPosition.dy, greaterThan(hiddenPosition.dy));
    expect(returningPosition.dy, lessThan(initialPosition.dy));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('item-3')).dy,
        closeTo(initialPosition.dy, 0.1));
  });

  testWidgets('animates the next switch after a reversed transition settles',
      (tester) async {
    late StateSetter update;
    var items = [_item(1), _item(2), _item(3), _item(4)];
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 250,
                child: SearchResultGrid(
                  items: items,
                  crossCount: 2,
                  cardExtent: 100,
                  itemBuilder: _card,
                  scrollController: scrollController,
                ),
              ),
            ),
          );
        },
      ),
    );

    update(() => items = [_item(1), _item(3)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));
    update(() => items = [_item(1), _item(2), _item(3), _item(4)]);
    await tester.pumpAndSettle();

    update(() => items = [_item(1), _item(3)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));

    expect(find.text('item-2'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('item-2'), findsNothing);
  });

  testWidgets('preserves refreshed card content while reversing',
      (tester) async {
    late StateSetter update;
    var items = [_item(1), _item(2), _item(3), _item(4)];
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 250,
                child: SearchResultGrid(
                  items: items,
                  crossCount: 2,
                  cardExtent: 100,
                  itemBuilder: (context, item) => Text(item.nameCn),
                  scrollController: scrollController,
                ),
              ),
            ),
          );
        },
      ),
    );

    update(() => items = [_item(1), _item(3)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));
    update(() => items = [_item(1), _item(2), _item(3), _item(4)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 105));

    final refreshedItems = [_item(1), _item(2), _item(3), _item(4)];
    refreshedItems.first.nameCn = 'updated-name';
    update(() => items = refreshedItems);
    await tester.pumpAndSettle();

    expect(find.text('updated-name'), findsOneWidget);
  });

  testWidgets('resumes toward the target when toggled during a reverse',
      (tester) async {
    late StateSetter update;
    var items = [_item(1), _item(2), _item(3), _item(4)];
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 250,
                child: SearchResultGrid(
                  items: items,
                  crossCount: 2,
                  cardExtent: 100,
                  itemBuilder: _card,
                  scrollController: scrollController,
                ),
              ),
            ),
          );
        },
      ),
    );

    update(() => items = [_item(1), _item(3)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));
    update(() => items = [_item(1), _item(2), _item(3), _item(4)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 105));
    final reversingPosition = tester.getTopLeft(find.text('item-3'));

    update(() => items = [_item(1), _item(3)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 105));
    final resumedPosition = tester.getTopLeft(find.text('item-3'));

    expect(resumedPosition.dy, lessThan(reversingPosition.dy));
    await tester.pumpAndSettle();
    expect(find.text('item-2'), findsNothing);
  });

  testWidgets('keeps the current scroll position when switching views',
      (tester) async {
    late StateSetter update;
    var items = List<BangumiItem>.generate(12, (index) => _item(index + 1));
    final scrollController = ScrollController();
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 250,
                child: SearchResultGrid(
                  items: items,
                  crossCount: 2,
                  cardExtent: 100,
                  itemBuilder: _card,
                  scrollController: scrollController,
                ),
              ),
            ),
          );
        },
      ),
    );
    scrollController.jumpTo(208);
    await tester.pump();
    update(() => items = [
          _item(1),
          _item(2),
          _item(5),
          _item(6),
          _item(7),
          _item(8),
          _item(9),
          _item(10),
          _item(11),
          _item(12),
        ]);
    await tester.pumpAndSettle();
    expect(scrollController.offset, closeTo(208, 2));

    update(() =>
        items = List<BangumiItem>.generate(12, (index) => _item(index + 1)));
    await tester.pumpAndSettle();

    expect(scrollController.offset, closeTo(208, 2));
    expect(find.text('item-5'), findsOneWidget);
  });

  testWidgets('lazily builds a settled large result list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 250,
            child: SearchResultGrid(
              items: List<BangumiItem>.generate(100, (i) => _item(i + 1)),
              crossCount: 2,
              cardExtent: 100,
              itemBuilder: _card,
              scrollController: ScrollController(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('item-1'), findsOneWidget);
    expect(find.text('item-100'), findsNothing);
  });

  testWidgets('uses one column when cross count is zero', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchResultGrid(
            items: [_item(1)],
            crossCount: 0,
            cardExtent: 100,
            itemBuilder: _card,
            scrollController: ScrollController(),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('item-1'), findsOneWidget);
  });

  testWidgets('allows scrolling while a view transition is running',
      (tester) async {
    late StateSetter update;
    var items = List<BangumiItem>.generate(60, (i) => _item(i + 1));
    final scrollController = ScrollController();
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 250,
                child: SearchResultGrid(
                  items: items,
                  crossCount: 2,
                  cardExtent: 100,
                  itemBuilder: _card,
                  scrollController: scrollController,
                ),
              ),
            ),
          );
        },
      ),
    );

    update(() => items = items.where((item) => item.id.isOdd).toList());
    await tester.pump();
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -180),
    );
    await tester.pump();

    expect(scrollController.offset, greaterThan(0));
    await tester.pumpAndSettle();
  });

  testWidgets('does not rebuild card contents on each animation frame',
      (tester) async {
    late StateSetter update;
    var items = List<BangumiItem>.generate(12, (i) => _item(i + 1));
    var cardBuilds = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 250,
                child: SearchResultGrid(
                  items: items,
                  crossCount: 2,
                  cardExtent: 100,
                  itemBuilder: (context, item) {
                    cardBuilds++;
                    return _card(context, item);
                  },
                  scrollController: ScrollController(),
                ),
              ),
            ),
          );
        },
      ),
    );

    update(() => items = items.where((item) => item.id.isOdd).toList());
    await tester.pump();
    final buildsAtTransitionStart = cardBuilds;
    await tester.pump(const Duration(milliseconds: 100));

    expect(cardBuilds, buildsAtTransitionStart);
    await tester.pumpAndSettle();
  });
}
