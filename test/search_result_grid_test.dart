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

    update(() => items = [_item(1), _item(3)]);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('item-2'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('item-2'), findsNothing);
    expect(find.text('item-3'), findsOneWidget);
  });

  testWidgets('preserves the visible anchor after restoring the all list',
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
    expect(scrollController.offset, closeTo(100, 2));

    update(() =>
        items = List<BangumiItem>.generate(12, (index) => _item(index + 1)));
    await tester.pumpAndSettle();

    expect(scrollController.offset, closeTo(208, 2));
    expect(find.text('item-5'), findsOneWidget);
  });
}
