import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/gamepad_navigation.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/services/platform/gamepad_input_service.dart';
import 'package:universal_gamepad/universal_gamepad.dart';

void main() {
  testWidgets('B closes a modal and restores the underlying page focus',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    final pageFocus = FocusNode();
    late BuildContext pageContext;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [topRouteObserver],
      builder: (context, child) => GamepadNavigationScope(
        service: service,
        child: child!,
      ),
      home: Builder(builder: (context) {
        pageContext = context;
        return Scaffold(
            body: TextButton(
          focusNode: pageFocus,
          onPressed: () {},
          child: const Text('page action'),
        ));
      }),
    ));
    pageFocus.requestFocus();
    await tester.pumpAndSettle();
    unawaited(showDialog<void>(
      context: pageContext,
      builder: (context) => AlertDialog(
        title: const Text('modal'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('close'),
          )
        ],
      ),
    ));
    await tester.pumpAndSettle();
    service.handleEvent(GamepadButtonEvent(
      gamepadId: 1,
      timestamp: 1,
      button: GamepadButton.b,
      pressed: true,
      value: 1,
    ));
    await tester.pumpAndSettle();
    expect(find.text('modal'), findsNothing);
    expect(find.text('page action'), findsOneWidget);
    expect(pageFocus.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    service.reset();
    pageFocus.dispose();
  });

  testWidgets('backgrounding releases held controller navigation',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    final events = <GamepadCommandEvent>[];
    final subscription = service.commands.listen(events.add);
    await tester.pumpWidget(MaterialApp(
        home: GamepadNavigationScope(
      service: service,
      child: const Scaffold(body: Text('page')),
    )));
    service.handleEvent(GamepadButtonEvent(
      gamepadId: 1,
      timestamp: 1,
      button: GamepadButton.dpadDown,
      pressed: true,
      value: 1,
    ));
    await tester.pump();
    expect(events.length, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 1));
    expect(events.length, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(subscription.cancel());
    service.reset();
  });

  GamepadButtonEvent button(GamepadButton button, bool pressed) {
    return GamepadButtonEvent(
      gamepadId: 1,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      button: button,
      pressed: pressed,
      value: pressed ? 1 : 0,
    );
  }

  GamepadAxisEvent axis(GamepadAxis axis, double value) {
    return GamepadAxisEvent(
      gamepadId: 1,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      axis: axis,
      value: value,
    );
  }

  testWidgets('virtual arrow and gamepad axis move focus only once',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    final first = FocusNode();
    final second = FocusNode();
    final third = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: GamepadNavigationScope(
          service: service,
          child: Scaffold(
            body: Row(
              children: [
                TextButton(
                  focusNode: first,
                  onPressed: () {},
                  child: const Text('first'),
                ),
                TextButton(
                  focusNode: second,
                  onPressed: () {},
                  child: const Text('second'),
                ),
                TextButton(
                  focusNode: third,
                  onPressed: () {},
                  child: const Text('third'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    first.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(second.hasFocus, isTrue);

    service.handleEvent(axis(GamepadAxis.leftStickX, 0.9));
    await tester.pump();
    expect(second.hasFocus, isTrue);
    expect(third.hasFocus, isFalse);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    service.handleEvent(axis(GamepadAxis.leftStickX, 0.95));
    await tester.pump();
    expect(second.hasFocus, isTrue);
    service.handleEvent(axis(GamepadAxis.leftStickX, 0.0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    service.reset();
    first.dispose();
    second.dispose();
    third.dispose();
  });

  testWidgets('native B suppresses a virtual keyboard activation',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    final focusNode = FocusNode();
    var activations = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: GamepadNavigationScope(
          service: service,
          child: Scaffold(
            body: TextButton(
              focusNode: focusNode,
              onPressed: () => activations++,
              child: const Text('action'),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    service.handleEvent(button(GamepadButton.b, true));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 120));

    expect(activations, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    service.reset();
    focusNode.dispose();
  });

  testWidgets('native B also cancels an activation that arrived first',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    final focusNode = FocusNode();
    var activations = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: GamepadNavigationScope(
          service: service,
          child: Scaffold(
            body: TextButton(
              focusNode: focusNode,
              onPressed: () => activations++,
              child: const Text('action'),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    service.handleEvent(button(GamepadButton.b, true));
    await tester.pump(const Duration(milliseconds: 120));

    expect(activations, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    service.reset();
    focusNode.dispose();
  });

  testWidgets('a native A and its virtual keyboard copy activate once',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    final focusNode = FocusNode();
    var activations = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: GamepadNavigationScope(
          service: service,
          child: Scaffold(
            body: TextButton(
              focusNode: focusNode,
              onPressed: () => activations++,
              child: const Text('action'),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    service.handleEvent(button(GamepadButton.a, true));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 120));

    expect(activations, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    service.reset();
    focusNode.dispose();
  });

  testWidgets('keyboard activation is preserved when no native button arrives',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    final focusNode = FocusNode();
    var activations = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: GamepadNavigationScope(
          service: service,
          child: Scaffold(
            body: TextButton(
              focusNode: focusNode,
              onPressed: () => activations++,
              child: const Text('action'),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 120));

    expect(activations, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    service.reset();
    focusNode.dispose();
  });

  testWidgets('Y keeps text focus and delegates to the page context action',
      (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    final service = GamepadInputService(events: const Stream.empty());
    var contextActions = 0;
    String? submitted;
    await tester.pumpWidget(MaterialApp(
      home: GamepadNavigationScope(
        service: service,
        child: Actions(
          actions: {
            GamepadContextActionIntent:
                CallbackAction<GamepadContextActionIntent>(onInvoke: (_) {
              contextActions++;
              return null;
            }),
          },
          child: Scaffold(
            body: TextField(
              focusNode: focus,
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => submitted = value,
            ),
          ),
        ),
      ),
    ));
    await tester.showKeyboard(find.byType(TextField));
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: '动画',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 0, end: 2),
    ));
    await tester.pump();
    service.handleEvent(button(GamepadButton.y, true));
    service.handleEvent(button(GamepadButton.y, false));
    await tester.pump();
    expect(contextActions, 1);
    expect(focus.hasFocus, isTrue);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(controller.value.composing, const TextRange(start: 0, end: 2));
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(submitted, '动画');
    await tester.pumpWidget(const SizedBox.shrink());
    service.reset();
    controller.dispose();
    focus.dispose();
  });

  testWidgets('text arrow keys do not become gamepad navigation',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    final controller = TextEditingController(text: 'abc');
    final focus = FocusNode();
    final commands = <GamepadCommand>[];
    final subscription = service.commands.listen((event) {
      commands.add(event.command);
    });
    await tester.pumpWidget(MaterialApp(
      home: GamepadNavigationScope(
        service: service,
        child: Scaffold(
            body: TextField(
          controller: controller,
          focusNode: focus,
        )),
      ),
    ));
    await tester.showKeyboard(find.byType(TextField));
    controller.selection = const TextSelection.collapsed(offset: 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.selection.baseOffset, 1);
    expect(commands, isEmpty);
    expect(focus.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(subscription.cancel());
    service.reset();
    controller.dispose();
    focus.dispose();
  });

  testWidgets('pointer input hides hints and controller restores navigation',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    final first = FocusNode();
    final second = FocusNode();
    await tester.pumpWidget(MaterialApp(
      home: GamepadNavigationScope(
        service: service,
        child: Scaffold(
            body: Row(children: [
          TextButton(
              focusNode: first, onPressed: () {}, child: const Text('one')),
          TextButton(
              focusNode: second, onPressed: () {}, child: const Text('two')),
        ])),
      ),
    ));
    first.requestFocus();
    await tester.pump();
    service.handleEvent(axis(GamepadAxis.leftStickX, 0.9));
    service.handleEvent(axis(GamepadAxis.leftStickX, 0));
    await tester.pump();
    expect(second.hasFocus, isTrue);
    expect(service.usingGamepad.value, isTrue);
    await tester.tap(find.text('one'));
    await tester.pump();
    expect(service.usingGamepad.value, isFalse);
    first.requestFocus();
    await tester.pump();
    service.handleEvent(axis(GamepadAxis.leftStickX, -0.9));
    service.handleEvent(axis(GamepadAxis.leftStickX, 0));
    await tester.pump();
    expect(service.usingGamepad.value, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    service.reset();
    first.dispose();
    second.dispose();
  });

  testWidgets('joystick leaves a focused text field instead of trapping',
      (tester) async {
    // A focused text field must not swallow directional input as cursor
    // movement; the stick has to be able to move on to the next control.
    final service = GamepadInputService(events: const Stream.empty());
    final textFocus = FocusNode(debugLabel: 'danmaku input');
    final buttonFocus = FocusNode(debugLabel: 'next button');
    await tester.pumpWidget(MaterialApp(
      home: GamepadNavigationScope(
        service: service,
        child: Scaffold(
          body: Row(children: [
            SizedBox(
              width: 220,
              child: TextField(
                focusNode: textFocus,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'danmaku'),
              ),
            ),
            TextButton(
              focusNode: buttonFocus,
              onPressed: () {},
              child: const Text('next'),
            ),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(textFocus.hasPrimaryFocus, isTrue);

    service.handleEvent(button(GamepadButton.dpadRight, true));
    service.handleEvent(button(GamepadButton.dpadRight, false));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(buttonFocus.hasPrimaryFocus, isTrue,
        reason: 'right must move focus out of the text field');
    await tester.pumpWidget(const SizedBox.shrink());
    service.reset();
    textFocus.dispose();
    buttonFocus.dispose();
  });
}
