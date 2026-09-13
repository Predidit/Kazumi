import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_focus_navigation.dart';
import 'package:kazumi/bean/widget/tv_focusable_surface.dart';
import 'package:kazumi/bean/widget/tv_player_side_panel.dart';
import 'package:kazumi/services/platform/tv_navigation.dart';

void main() {
  test('row wrap handles both edges and one item', () {
    expect(tvWrappedIndex(0, -1, 8), 7);
    expect(tvWrappedIndex(7, 1, 8), 0);
    expect(tvWrappedIndex(0, -1, 1), 0);
  });

  test('grid wraps ragged rows without selecting nonexistent episodes', () {
    expect(tvGridTarget(0, 10, 4, TraversalDirection.left), 3);
    expect(tvGridTarget(3, 10, 4, TraversalDirection.right), 0);
    expect(tvGridTarget(8, 10, 4, TraversalDirection.left), 9);
    expect(tvGridTarget(9, 10, 4, TraversalDirection.right), 8);
    expect(tvGridTarget(0, 10, 4, TraversalDirection.up), 8);
    expect(tvGridTarget(3, 10, 4, TraversalDirection.up), 7);
    expect(tvGridTarget(9, 10, 4, TraversalDirection.down), 1);
    for (var count = 1; count <= 100; count++) {
      for (var index = 0; index < count; index++) {
        for (final direction in TraversalDirection.values) {
          expect(tvGridTarget(index, count, 4, direction),
              inInclusiveRange(0, count - 1));
        }
      }
    }
  });

  for (final axis in Axis.values) {
    testWidgets('page policy cycles $axis in both directions', (tester) async {
      final nodes = List.generate(3, (_) => FocusNode());
      addTearDown(() {
        for (final node in nodes) {
          node.dispose();
        }
      });
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: FocusTraversalGroup(
          policy: TvLoopTraversalPolicy(),
          child: Flex(direction: axis, children: [
            for (var index = 0; index < 3; index++)
              TvFocusableSurface(
                  enabled: true,
                  autofocus: index == 0,
                  focusNode: nodes[index],
                  onPressed: () {},
                  child: const SizedBox(width: 90, height: 90)),
          ]),
        ),
      )));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(axis == Axis.horizontal
          ? LogicalKeyboardKey.arrowLeft
          : LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(nodes.last.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(axis == Axis.horizontal
          ? LogicalKeyboardKey.arrowRight
          : LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(nodes.first.hasPrimaryFocus, isTrue);
    });
  }

  testWidgets(
      'detail PLAY fires once, repeats and typing do not start playback',
      (tester) async {
    var plays = 0;
    final editFocus = FocusNode();
    addTearDown(editFocus.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: TvDetailPlayShortcut(
          onPlay: () async {
            plays++;
          },
          child: Column(children: [
            TextButton(
                autofocus: true, onPressed: () {}, child: const Text('watch')),
            TextField(focusNode: editFocus),
          ])),
    )));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.mediaPlay);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.mediaPlay);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.mediaPlay);
    expect(plays, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    expect(plays, 2);
    editFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
    expect(plays, 2);
  });

  testWidgets('covered detail route does not handle PLAY for a dialog',
      (tester) async {
    var plays = 0;
    late BuildContext pageContext;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      pageContext = context;
      return TvDetailPlayShortcut(
          onPlay: () async {
            plays++;
          },
          child: TextButton(
              autofocus: true, onPressed: () {}, child: const Text('watch')));
    })));
    await tester.pumpAndSettle();
    showDialog<void>(
        context: pageContext,
        builder: (_) => AlertDialog(
              actions: [
                TextButton(
                    autofocus: true,
                    onPressed: () {},
                    child: const Text('cancel'))
              ],
            ));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
    expect(plays, 0);
  });

  for (final brightness in Brightness.values) {
    testWidgets('side panel keeps a translucent theme tint in $brightness',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const TvPlayerSidePanel(child: SizedBox.expand())));
      final box = tester.widget<ColoredBox>(find.descendant(
          of: find.byType(TvPlayerSidePanel),
          matching: find.byType(ColoredBox)));
      expect(box.color.a, closeTo(0.64, 0.005));
    });
  }
}
