import 'dart:async';
import 'dart:ui' show ViewFocusEvent, ViewFocusState, ViewFocusDirection;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/gamepad_navigation.dart';
import 'package:kazumi/services/platform/gamepad_input_service.dart';
import 'package:universal_gamepad/universal_gamepad.dart';

void main() {
  testWidgets(
      'key release is observed even when the new focused child consumes it',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    final focus = FocusNode();
    final events = <GamepadCommandEvent>[];
    final sub = service.commands.listen(events.add);
    var swallow = false;
    await tester.pumpWidget(MaterialApp(
        home: GamepadNavigationScope(
      service: service,
      child: Focus(
          focusNode: focus,
          autofocus: true,
          onKeyEvent: (_, event) =>
              swallow ? KeyEventResult.handled : KeyEventResult.ignored,
          child: const SizedBox.expand()),
    )));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    swallow = true;
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    final released = events.length;
    await tester.pump(const Duration(seconds: 1));
    expect(events.length, released);
    await tester.pumpWidget(const SizedBox.shrink());
    focus.dispose();
    unawaited(sub.cancel());
    unawaited(service.dispose());
  });

  testWidgets(
      'desktop view focus loss blocks native input even while app is resumed',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    final focus = FocusNode();
    final events = <GamepadCommandEvent>[];
    final sub = service.commands.listen(events.add);
    await tester.pumpWidget(MaterialApp(
        home: GamepadNavigationScope(
      service: service,
      child: Focus(
          focusNode: focus, autofocus: true, child: const SizedBox.expand()),
    )));
    await tester.pump();
    void press(bool pressed) => service.handleEvent(GamepadButtonEvent(
        gamepadId: 1,
        timestamp: 0,
        button: GamepadButton.dpadDown,
        pressed: pressed,
        value: pressed ? 1 : 0));
    press(true);
    tester.binding.handleViewFocusChanged(ViewFocusEvent(
        viewId: tester.view.viewId,
        state: ViewFocusState.unfocused,
        direction: ViewFocusDirection.undefined));
    press(false);
    press(true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(events, hasLength(1));
    tester.binding.handleViewFocusChanged(ViewFocusEvent(
        viewId: tester.view.viewId,
        state: ViewFocusState.focused,
        direction: ViewFocusDirection.undefined));
    press(false);
    press(true);
    expect(events, hasLength(2));
    press(false);
    await tester.pumpWidget(const SizedBox.shrink());
    focus.dispose();
    unawaited(sub.cancel());
    unawaited(service.dispose());
  });

  testWidgets(
      'gamepad uses slider actions and vertical movement leaves the slider',
      (tester) async {
    final service = GamepadInputService(
        events: const Stream.empty(), duplicateWindow: Duration.zero);
    final slider = FocusNode();
    final next = FocusNode();
    var value = 0.5;
    await tester.pumpWidget(MaterialApp(
        home: GamepadNavigationScope(
      service: service,
      child: StatefulBuilder(
          builder: (context, setState) => Scaffold(
                  body: Column(children: [
                Slider(
                    focusNode: slider,
                    value: value,
                    onChanged: (v) => setState(() => value = v)),
                TextButton(
                    focusNode: next,
                    onPressed: () {},
                    child: const Text('next')),
              ]))),
    )));
    slider.requestFocus();
    await tester.pump();
    Future<void> press(GamepadButton button) async {
      service.handleEvent(GamepadButtonEvent(
          gamepadId: 1, timestamp: 0, button: button, pressed: true, value: 1));
      service.handleEvent(GamepadButtonEvent(
          gamepadId: 1,
          timestamp: 0,
          button: button,
          pressed: false,
          value: 0));
      await tester.pumpAndSettle();
    }

    await press(GamepadButton.dpadRight);
    expect(value, greaterThan(0.5));
    expect(slider.hasFocus, isTrue);
    await press(GamepadButton.dpadDown);
    expect(next.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    slider.dispose();
    next.dispose();
    unawaited(service.dispose());
  });
}
