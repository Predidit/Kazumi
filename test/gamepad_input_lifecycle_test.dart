import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/platform/gamepad_input_service.dart';
import 'package:universal_gamepad/universal_gamepad.dart';

GamepadAxisEvent axis(double value, {int id = 1}) => GamepadAxisEvent(
    gamepadId: id, timestamp: 0, axis: GamepadAxis.leftStickX, value: value);

void main() {
  testWidgets('deduplicated delayed node still repeats a sustained hold',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    final events = <GamepadCommandEvent>[];
    final sub = service.commands.listen(events.add);
    service.handleEvent(axis(1));
    service.handleEvent(axis(0));
    service.handleEvent(axis(1, id: 2));
    expect(events, hasLength(1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(events, hasLength(2));
    expect(events.last.isRepeat, isTrue);
    service.handleEvent(axis(0, id: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(events, hasLength(2));
    service.reset();
    unawaited(sub.cancel());
    unawaited(service.dispose());
  });

  for (final resetOnRepeat in [false, true]) {
    testWidgets(
        'reset inside ${resetOnRepeat ? 'repeat' : 'press'} leaves no repeat timer',
        (tester) async {
      final service = GamepadInputService(events: const Stream.empty());
      var count = 0;
      final sub = service.commands.listen((event) {
        count++;
        if (event.isRepeat == resetOnRepeat) service.reset();
      });
      service.handleEvent(axis(1));
      await tester.pump(const Duration(milliseconds: 250));
      final expected = resetOnRepeat ? 2 : 1;
      expect(count, expected);
      await tester.pump(const Duration(seconds: 1));
      expect(count, expected);
      // Do not reset here: pending timers must fail the widget test.
      unawaited(sub.cancel());
    });
  }

  testWidgets(
      'background events cannot re-arm input and resume accepts a new press',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    final events = <GamepadCommandEvent>[];
    final sub = service.commands.listen(events.add);
    service.handleEvent(axis(1));
    service.setSuspended(true);
    service.handleEvent(axis(-1));
    service.handleKeyboardNavigation(GamepadCommand.navigateDown, true);
    await tester.pump(const Duration(seconds: 3));
    expect(events, hasLength(1));
    service.setSuspended(false);
    service.handleEvent(axis(-1));
    expect(events.last.command, GamepadCommand.navigateLeft);
    service.handleEvent(axis(0));
    await tester.pump(const Duration(seconds: 3));
    expect(events, hasLength(2));
    service.reset();
    unawaited(sub.cancel());
    unawaited(service.dispose());
  });

  testWidgets(
      'silent keyboard source expires but an unchanged native hold continues',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    final events = <GamepadCommandEvent>[];
    final sub = service.commands.listen(events.add);
    service.handleKeyboardNavigation(GamepadCommand.navigateDown, true);
    await tester.pump(const Duration(seconds: 3));
    final afterTimeout = events.length;
    await tester.pump(const Duration(seconds: 1));
    expect(events.length, afterTimeout);
    service.handleEvent(axis(1));
    await tester.pump(const Duration(seconds: 3));
    expect(events.last.command, GamepadCommand.navigateRight);
    expect(events.last.isRepeat, isTrue);
    service.handleEvent(axis(0));
    final released = events.length;
    await tester.pump(const Duration(seconds: 1));
    expect(events.length, released);
    service.reset();
    unawaited(sub.cancel());
    unawaited(service.dispose());
  });
}
