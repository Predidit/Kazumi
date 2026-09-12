import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/platform/gamepad_input_service.dart';
import 'package:universal_gamepad/universal_gamepad.dart';

void main() {
  GamepadButtonEvent button(
    GamepadButton button,
    bool pressed, {
    int id = 1,
    double? value,
  }) {
    return GamepadButtonEvent(
      gamepadId: id,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      button: button,
      pressed: pressed,
      value: value ?? (pressed ? 1 : 0),
    );
  }

  GamepadAxisEvent axis(
    GamepadAxis axis,
    double value, {
    int id = 1,
  }) {
    return GamepadAxisEvent(
      gamepadId: id,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      axis: axis,
      value: value,
    );
  }

  GamepadConnectionEvent disconnect({int id = 1}) {
    return GamepadConnectionEvent(
      gamepadId: id,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      connected: false,
      info: GamepadInfo(id: id, name: 'Test gamepad'),
    );
  }

  test('face buttons emit semantic commands once per press', () async {
    final service = GamepadInputService(events: const Stream.empty());
    final events = <GamepadCommandEvent>[];
    final subscription = service.commands.listen(events.add);

    service.handleEvent(button(GamepadButton.a, true));
    service.handleEvent(button(GamepadButton.a, true));
    service.handleEvent(button(GamepadButton.a, false));
    service.handleEvent(button(GamepadButton.b, true));

    expect(
      events.map((event) => event.command),
      <GamepadCommand>[GamepadCommand.activate, GamepadCommand.back],
    );
    await subscription.cancel();
    await service.dispose();
  });

  test('left stick applies dead zone, dominance, and release hysteresis',
      () async {
    final service = GamepadInputService(
      events: const Stream.empty(),
      stickDeadZone: 0.5,
    );
    final events = <GamepadCommandEvent>[];
    final subscription = service.commands.listen(events.add);

    service.handleEvent(axis(GamepadAxis.leftStickY, -0.4));
    expect(events, isEmpty);

    service.handleEvent(axis(GamepadAxis.leftStickY, -0.8));
    service.handleEvent(axis(GamepadAxis.leftStickY, -0.55));
    expect(events.map((event) => event.command), [GamepadCommand.navigateUp]);

    service.handleEvent(axis(GamepadAxis.leftStickY, -0.1));
    service.handleEvent(axis(GamepadAxis.leftStickX, -0.9));
    expect(
      events.map((event) => event.command),
      [GamepadCommand.navigateUp, GamepadCommand.navigateLeft],
    );
    await subscription.cancel();
    await service.dispose();
  });

  test('holding a stick past the dead zone moves focus exactly once', () async {
    final service = GamepadInputService(
      events: const Stream.empty(),
      stickDeadZone: 0.5,
      initialRepeatDelay: const Duration(hours: 1),
    );
    final events = <GamepadCommandEvent>[];
    final subscription = service.commands.listen(events.add);

    // A real stick streams a ramp of values while held.
    for (final value in <double>[0.6, 0.7, 0.85, 0.95, 1.0, 0.9]) {
      service.handleEvent(axis(GamepadAxis.leftStickX, value));
    }

    expect(
      events.map((event) => event.command),
      [GamepadCommand.navigateRight],
    );
    await subscription.cancel();
    await service.dispose();
  });

  test('duplicate device nodes for one physical stick emit a single step',
      () async {
    // Handhelds expose one physical pad through several nodes at once: a native
    // node, an xpad compatibility node, and virtual pads from Handheld Daemon
    // or Steam Input. Each reports the same flick.
    final service = GamepadInputService(
      events: const Stream.empty(),
      stickDeadZone: 0.5,
      initialRepeatDelay: const Duration(hours: 1),
    );
    final events = <GamepadCommandEvent>[];
    final subscription = service.commands.listen(events.add);

    service.handleEvent(axis(GamepadAxis.leftStickY, 0.9, id: 1));
    service.handleEvent(axis(GamepadAxis.leftStickY, 0.9, id: 2));
    service.handleEvent(axis(GamepadAxis.leftStickY, 0.9, id: 3));

    expect(
      events.map((event) => event.command),
      [GamepadCommand.navigateDown],
    );

    // Releasing only some nodes keeps the command held, so no extra step fires
    // when the remaining nodes release.
    service.handleEvent(axis(GamepadAxis.leftStickY, 0.0, id: 1));
    service.handleEvent(axis(GamepadAxis.leftStickY, 0.0, id: 2));
    service.handleEvent(axis(GamepadAxis.leftStickY, 0.0, id: 3));
    expect(events.length, 1);

    // A fresh flick after full release moves once more, once it is clearly a
    // separate physical action rather than a duplicate report.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    service.handleEvent(axis(GamepadAxis.leftStickY, 0.9, id: 1));
    service.handleEvent(axis(GamepadAxis.leftStickY, 0.9, id: 2));
    expect(
      events.map((event) => event.command),
      [GamepadCommand.navigateDown, GamepadCommand.navigateDown],
    );
    await subscription.cancel();
    await service.dispose();
  });

  test('axis and dpad on one device share one held navigation state', () async {
    final service = GamepadInputService(
      events: const Stream.empty(),
      stickDeadZone: 0.5,
      initialRepeatDelay: const Duration(hours: 1),
      duplicateWindow: Duration.zero,
    );
    final events = <GamepadCommandEvent>[];
    final subscription = service.commands.listen(events.add);

    service.handleEvent(axis(GamepadAxis.leftStickY, 0.9));
    service.handleEvent(button(GamepadButton.dpadDown, true));
    service.handleEvent(button(GamepadButton.dpadDown, false));

    // Releasing the synthetic D-pad must not release the still-held axis.
    service.handleEvent(axis(GamepadAxis.leftStickY, 0.95));
    expect(
      events.map((event) => event.command),
      [GamepadCommand.navigateDown],
    );

    service.handleEvent(axis(GamepadAxis.leftStickY, 0.0));
    await subscription.cancel();
    await service.dispose();
  });

  test('keyboard arrow and gamepad axis share one held navigation state',
      () async {
    final service = GamepadInputService(
      events: const Stream.empty(),
      stickDeadZone: 0.5,
      initialRepeatDelay: const Duration(hours: 1),
      duplicateWindow: Duration.zero,
    );
    final events = <GamepadCommandEvent>[];
    final subscription = service.commands.listen(events.add);

    service.handleKeyboardNavigation(GamepadCommand.navigateRight, true);
    service.handleEvent(axis(GamepadAxis.leftStickX, 0.9));
    service.handleKeyboardNavigation(GamepadCommand.navigateRight, false);

    // HHD's virtual arrow can release before the gamepad axis. The axis stays
    // held and must not create a second rising edge on its next report.
    service.handleEvent(axis(GamepadAxis.leftStickX, 0.95));
    expect(
      events.map((event) => event.command),
      [GamepadCommand.navigateRight],
    );

    service.handleEvent(axis(GamepadAxis.leftStickX, 0.0));
    await subscription.cancel();
    await service.dispose();
  });

  test('lost keyboard KeyUp is released by the navigation watchdog', () async {
    final service = GamepadInputService(
      events: const Stream.empty(),
      duplicateWindow: Duration.zero,
      keyboardHoldTimeout: const Duration(milliseconds: 20),
      initialRepeatDelay: const Duration(hours: 1),
    );
    final events = <GamepadCommandEvent>[];
    final subscription = service.commands.listen(events.add);

    service.handleKeyboardNavigation(GamepadCommand.navigateLeft, true);
    await Future<void>.delayed(const Duration(milliseconds: 35));
    // No KeyUp arrived. A fresh press must still produce a new edge after the
    // watchdog has released the stale virtual-keyboard source.
    service.handleKeyboardNavigation(GamepadCommand.navigateLeft, true);

    expect(
      events.map((event) => event.command),
      [GamepadCommand.navigateLeft, GamepadCommand.navigateLeft],
    );
    await subscription.cancel();
    await service.dispose();
  });

  test('duplicate nodes reporting the same flick out of step emit one step',
      () async {
    // Nodes for one physical stick do not report in lockstep: one can cross the
    // threshold and fall back to centre before another crosses it at all.
    // Command-level merging alone still sees two press/release cycles here.
    final service = GamepadInputService(
      events: const Stream.empty(),
      stickDeadZone: 0.5,
      initialRepeatDelay: const Duration(hours: 1),
    );
    final events = <GamepadCommandEvent>[];
    final subscription = service.commands.listen(events.add);

    service.handleEvent(axis(GamepadAxis.leftStickY, 0.9, id: 1));
    service.handleEvent(axis(GamepadAxis.leftStickY, 0.0, id: 1));
    service.handleEvent(axis(GamepadAxis.leftStickY, 0.9, id: 2));
    service.handleEvent(axis(GamepadAxis.leftStickY, 0.0, id: 2));

    expect(
      events.map((event) => event.command),
      [GamepadCommand.navigateDown],
    );
    await subscription.cancel();
    await service.dispose();
  });

  test('a deliberate second flick after the merge window still moves focus',
      () async {
    final service = GamepadInputService(
      events: const Stream.empty(),
      stickDeadZone: 0.5,
      initialRepeatDelay: const Duration(hours: 1),
      duplicateWindow: const Duration(milliseconds: 30),
    );
    final events = <GamepadCommandEvent>[];
    final subscription = service.commands.listen(events.add);

    service.handleEvent(axis(GamepadAxis.leftStickY, 0.9));
    service.handleEvent(axis(GamepadAxis.leftStickY, 0.0));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    service.handleEvent(axis(GamepadAxis.leftStickY, 0.9));
    service.handleEvent(axis(GamepadAxis.leftStickY, 0.0));

    expect(events.length, 2);
    await subscription.cancel();
    await service.dispose();
  });

  test('duplicate device nodes for one button press emit a single command',
      () async {
    final service = GamepadInputService(events: const Stream.empty());
    final events = <GamepadCommandEvent>[];
    final subscription = service.commands.listen(events.add);

    service.handleEvent(button(GamepadButton.a, true, id: 1));
    service.handleEvent(button(GamepadButton.a, true, id: 2));
    expect(events.length, 1);

    service.handleEvent(button(GamepadButton.a, false, id: 1));
    service.handleEvent(button(GamepadButton.a, false, id: 2));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    service.handleEvent(button(GamepadButton.a, true, id: 1));
    expect(events.length, 2);

    await subscription.cancel();
    await service.dispose();
  });

  test('repeat is app-timed and stops immediately on release', () async {
    final service = GamepadInputService(
      events: const Stream.empty(),
      initialRepeatDelay: const Duration(milliseconds: 10),
      repeatInterval: const Duration(milliseconds: 10),
    );
    final events = <GamepadCommandEvent>[];
    final subscription = service.commands.listen(events.add);

    service.handleEvent(button(GamepadButton.dpadRight, true));
    await Future<void>.delayed(const Duration(milliseconds: 38));
    expect(events.length, greaterThanOrEqualTo(2));
    expect(events.first.isRepeat, isFalse);
    expect(events.skip(1).every((event) => event.isRepeat), isTrue);

    service.handleEvent(button(GamepadButton.dpadRight, false));
    final countAfterRelease = events.length;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(events.length, countAfterRelease);
    await subscription.cancel();
    await service.dispose();
  });

  test('disconnect releases everything that controller held', () async {
    final service = GamepadInputService(
      events: const Stream.empty(),
      initialRepeatDelay: const Duration(milliseconds: 10),
      repeatInterval: const Duration(milliseconds: 10),
    );
    final events = <GamepadCommandEvent>[];
    final subscription = service.commands.listen(events.add);

    service.handleEvent(button(GamepadButton.dpadDown, true));
    await Future<void>.delayed(const Duration(milliseconds: 25));
    service.handleEvent(disconnect());
    final countAfterDisconnect = events.length;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(events.length, countAfterDisconnect);

    // The command is free again, so another pad can drive it.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    service.handleEvent(button(GamepadButton.dpadDown, true, id: 2));
    expect(events.length, countAfterDisconnect + 1);
    await subscription.cancel();
    await service.dispose();
  });
}
