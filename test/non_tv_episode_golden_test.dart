import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/pages/video/episode_selection_panel.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final openMenu in [false, true]) {
      testWidgets('upstream mobile episode panel $brightness menu=$openMenu',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.green, brightness: brightness)),
          home: Scaffold(
              body: EpisodeSelectionPanel(
            title: 'Sample',
            roads: List.generate(
                2,
                (i) => Road(
                    name: 'Route ${i + 1}',
                    data: ['a', 'b'],
                    identifier: ['Episode 1', 'Episode 2'])),
            selectedRoad: 0,
            selectedEpisode: 1,
            downloads: const {},
            onEpisodeSelected: (_, __) {},
            disableAnimations: true,
          )),
        ));
        await tester.pumpAndSettle();
        if (openMenu) {
          await tester.tap(find.text('Route 1'));
          await tester.pumpAndSettle();
        }
        await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
                'goldens/upstream_episode_${brightness.name}_${openMenu ? "menu" : "panel"}.png'));
      });
    }
  }
}
