import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/episode_tile.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/pages/video/episode_selection_panel.dart';
import 'package:kazumi/services/platform/tv_mode.dart';

void main() {
  setUp(() => TvMode.setEnabledForTesting(true));
  tearDown(() => TvMode.setEnabledForTesting(false));

  testWidgets('TV road menu focuses choices and supports up down and confirm',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: EpisodeSelectionPanel(
            title: '线路测试',
            roads: List.generate(
                2,
                (i) =>
                    Road(name: '线路$i', data: ['url$i'], identifier: ['剧集$i'])),
            selectedRoad: 0,
            selectedEpisode: 1,
            downloads: const {},
            onEpisodeSelected: (_, __) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final anchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
    anchor.childFocusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    bool focused(int index) =>
        tester
            .widget<MenuItemButton>(find.byKey(ValueKey('road-option-$index')))
            .focusNode
            ?.hasFocus ==
        true;
    expect(focused(0), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focused(1), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(focused(0), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('road-option-0')), findsNothing);
    expect(find.text('剧集1'), findsOneWidget);
    expect(anchor.childFocusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(focused(1), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('road-option-1')), findsNothing);
    expect(anchor.childFocusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'TV panel locates recycled episode, wraps ragged row and activates exact road',
      (tester) async {
    final key = GlobalKey<EpisodeSelectionPanelState>();
    final selected = <List<int>>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 400,
      height: 460,
      child: EpisodeSelectionPanel(
        key: key,
        title: '离线选集布局验证',
        roads: [
          Road(
              name: '本地',
              data: List.generate(99, (i) => '$i'),
              identifier: List.generate(99, (i) => '第${i + 1}集'))
        ],
        selectedRoad: 0,
        selectedEpisode: 98,
        isOffline: true,
        downloads: const {},
        onEpisodeSelected: (episode, road) => selected.add([episode, road]),
      ),
    ))));
    await tester.pumpAndSettle();
    final reveal = key.currentState!.revealCurrentEpisode();
    await tester.pumpAndSettle();
    await reveal;
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'TV episode 0:98');
    final current = FocusManager.instance.primaryFocus!;
    expect(current.rect.bottom, lessThanOrEqualTo(460));
    for (final key in [
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'TV episode 0:97');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(selected, [
      [97, 0]
    ]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'TV episode 0:1');
    expect(find.byType(EpisodeTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
