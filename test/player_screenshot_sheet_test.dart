import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/controller/player_screenshot_controller.dart';
import 'package:kazumi/pages/player/player_screenshot_sheet.dart';

void main() {
  testWidgets('mouse double-click toggles only the clicked thumbnail', (
    tester,
  ) async {
    final controller = PlayerScreenshotController();
    addTearDown(controller.dispose);
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAABAAAAAJCAIAAAC0SDtlAAAAFUlEQVR4nGP4z8BAEiJN9agGWmkAACRlj3GqMTmoAAAAAElFTkSuQmCC',
    );
    for (final episode in ['A', 'B', 'C']) {
      await controller.capture(
        capturePng: () async => png,
        title: 'Test',
        episode: episode,
        position: Duration.zero,
        isCurrent: () => true,
      );
    }
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    showPlayerScreenshotSheet(
      tester.element(find.byType(Scaffold)),
      controller: controller,
    );
    await tester.pumpAndSettle();

    Finder thumbnail(int number) =>
        find.bySemanticsLabel(RegExp('查看第 $number 张'));
    Future<void> doubleClick(Finder target) async {
      await tester.tap(target, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 75));
      await tester.tap(target, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
    }

    await tester.tap(thumbnail(1), kind: PointerDeviceKind.mouse);
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(controller.selectedCount, 0);

    await doubleClick(thumbnail(2));
    expect(controller.candidates.where(controller.isSelected), [
      controller.candidates[1],
    ]);
    expect(find.text('保存 1 张'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    await doubleClick(thumbnail(2));
    expect(find.text('保存 2 张'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    final preview = find.byKey(ValueKey(controller.candidates.first.id));
    final viewer = tester.widget<InteractiveViewer>(
      find.descendant(of: preview, matching: find.byType(InteractiveViewer)),
    );
    for (final expectedScale in [2.0, 1.0]) {
      await doubleClick(preview);
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        expectedScale,
      );
      await tester.pump(kDoubleTapTimeout);
    }

    final exported = <String>[];
    await controller.save(
      chooseDestination: () async => 'test',
      write: (item, _) async => exported.add(item.episode),
    );
    await tester.pumpAndSettle();
    expect(exported, ['A', 'C']);
    expect(controller.candidates.single.episode, 'B');
    await tester.pumpWidget(const SizedBox());
  });
}
