import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/dialog/dialog.dart';
import 'package:kazumi/bean/dialog/exit_confirmation_dialog.dart';
import 'package:kazumi/bean/widget/gamepad_navigation.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/services/platform/gamepad_input_service.dart';
import 'package:universal_gamepad/universal_gamepad.dart';

void main() {
  GamepadButtonEvent button(GamepadButton button, bool pressed) {
    return GamepadButtonEvent(
      gamepadId: 1,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      button: button,
      pressed: pressed,
      value: pressed ? 1 : 0,
    );
  }

  testWidgets('gamepad can navigate and dismiss the exit dialog',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    addTearDown(service.reset);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        navigatorObservers: [KazumiDialog.observer, topRouteObserver],
        builder: (context, child) => GamepadNavigationScope(
          service: service,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: Center(child: Text('home'))),
      ),
    );
    await tester.pumpAndSettle();

    unawaited(KazumiDialog.show<ExitDialogResult>(
      builder: (_) => const ExitConfirmationDialog(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('关闭 Kazumi？'), findsOneWidget);

    Future<void> press(GamepadButton b) async {
      service.handleEvent(button(b, true));
      service.handleEvent(button(b, false));
      await tester.pumpAndSettle();
    }

    // The first gamepad press must land focus somewhere usable in the dialog.
    await press(GamepadButton.dpadDown);
    expect(tester.takeException(), isNull);
    final dialogFocus = FocusManager.instance.primaryFocus;
    expect(dialogFocus, isNotNull);
    expect(dialogFocus!.context, isNotNull);
    expect(
      ModalRoute.of(dialogFocus.context!)?.settings.name,
      'KazumiDialog',
      reason: 'focus should be inside the exit dialog',
    );

    // Walk down and activate until the "exit" option is selected. Before the
    // fix, A did nothing on the radio tiles and the confirm label never
    // changed.
    for (var i = 0; i < 4 && find.text('退出').evaluate().isEmpty; i++) {
      await press(GamepadButton.dpadDown);
      await press(GamepadButton.a);
      expect(tester.takeException(), isNull);
    }
    expect(find.text('退出'), findsOneWidget,
        reason: 'A should activate the focused exit option');

    // B dismisses the dialog and returns to the page.
    await press(GamepadButton.b);
    expect(tester.takeException(), isNull);
    expect(find.text('关闭 Kazumi？'), findsNothing);
    expect(find.text('home'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
