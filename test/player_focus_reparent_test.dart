import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/gamepad_navigation.dart';
import 'package:kazumi/services/platform/gamepad_input_service.dart';
import 'package:universal_gamepad/universal_gamepad.dart';

// Regression for the playback crash:
// 'child != this': Tried to make a child into a parent of itself.
// VideoPage and PlayerItem briefly attached the same FocusNode in nested
// Focus widgets. As soon as joystick focus moved, Flutter tried to reparent
// the node to itself. The fix keeps a single attachment inside the player
// area; this test locks that pattern and documents the constraint.
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

  testWidgets('single player focus survives joystick traversal to sibling',
      (tester) async {
    final service = GamepadInputService(events: const Stream.empty());
    final playerFocus = FocusNode(debugLabel: 'Video player shortcut scope');
    final panelScope = FocusScopeNode(debugLabel: 'Player controls');
    addTearDown(() {
      playerFocus.dispose();
      panelScope.dispose();
      service.reset();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GamepadNavigationScope(
          service: service,
          child: Scaffold(
            body: Column(
              children: [
                // Top bar sibling, outside the player Actions subtree, just
                // like VideoPage's back/refresh buttons.
                TextButton(
                  autofocus: true,
                  onPressed: () {},
                  child: const Text('top action'),
                ),
                Actions(
                  actions: <Type, Action<Intent>>{},
                  child: Focus(
                    focusNode: playerFocus,
                    autofocus: true,
                    child: FocusScope(
                      node: panelScope,
                      child: Column(
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: const Text('panel first'),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('panel second'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Drive joystick navigation the same way the player does: move within the
    // panel, then out toward the sibling top action. None of these steps may
    // throw 'child != this'.
    for (var i = 0; i < 4; i++) {
      service.handleEvent(button(GamepadButton.dpadDown, true));
      service.handleEvent(button(GamepadButton.dpadDown, false));
      await tester.pump(const Duration(milliseconds: 150));
    }
    for (var i = 0; i < 4; i++) {
      service.handleEvent(button(GamepadButton.dpadUp, true));
      service.handleEvent(button(GamepadButton.dpadUp, false));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(FocusManager.instance.primaryFocus, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('joystick moves between top bar and panel across scopes',
      (tester) async {
    // Mirrors the VideoPage/PlayerItem wiring: the panel lives in its own
    // traversal scope (directional traversal never leaves the nearest
    // scope), so up at the panel top edge hands focus to the top bar
    // explicitly, and down from the top bar hands it back.
    final service = GamepadInputService(events: const Stream.empty());
    final playerFocus = FocusNode(debugLabel: 'Video player shortcut scope');
    final panelScope = FocusScopeNode(debugLabel: 'Player controls');
    final topScope = FocusScopeNode(debugLabel: 'Video top bar');
    final topFirst = FocusNode(debugLabel: 'top first');
    final topSecond = FocusNode(debugLabel: 'top second');
    final panelFirst = FocusNode(debugLabel: 'panel first');
    final panelSecond = FocusNode(debugLabel: 'panel second');
    addTearDown(() {
      playerFocus.dispose();
      panelScope.dispose();
      topScope.dispose();
      topFirst.dispose();
      topSecond.dispose();
      panelFirst.dispose();
      panelSecond.dispose();
      service.reset();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GamepadNavigationScope(
          service: service,
          child: Scaffold(
            body: Column(
              children: [
                Actions(
                  actions: <Type, Action<Intent>>{
                    GamepadNavigateIntent:
                        CallbackAction<GamepadNavigateIntent>(
                      onInvoke: (intent) {
                        if (intent.direction == TraversalDirection.down) {
                          focusFirstGamepadControl(panelScope);
                          return null;
                        }
                        FocusManager.instance.primaryFocus
                            ?.focusInDirection(intent.direction);
                        return null;
                      },
                    ),
                  },
                  child: FocusScope(
                    node: topScope,
                    child: Row(
                      children: [
                        TextButton(
                          focusNode: topFirst,
                          onPressed: () {},
                          child: const Text('top first'),
                        ),
                        TextButton(
                          focusNode: topSecond,
                          onPressed: () {},
                          child: const Text('top second'),
                        ),
                      ],
                    ),
                  ),
                ),
                Actions(
                  actions: <Type, Action<Intent>>{
                    GamepadNavigateIntent:
                        CallbackAction<GamepadNavigateIntent>(
                      onInvoke: (intent) {
                        final focused = FocusManager.instance.primaryFocus;
                        final moved = focused?.focusInDirection(
                              intent.direction,
                            ) ??
                            false;
                        if (!moved &&
                            intent.direction == TraversalDirection.up) {
                          focusFirstGamepadControl(topScope);
                        }
                        return null;
                      },
                    ),
                  },
                  child: Focus(
                    focusNode: playerFocus,
                    child: FocusScope(
                      node: panelScope,
                      child: Column(
                        children: [
                          TextButton(
                            focusNode: panelFirst,
                            autofocus: true,
                            onPressed: () {},
                            child: const Text('panel first'),
                          ),
                          TextButton(
                            focusNode: panelSecond,
                            onPressed: () {},
                            child: const Text('panel second'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(panelFirst.hasPrimaryFocus, isTrue);

    // Up from the top edge of the panel must reach the top bar.
    service.handleEvent(button(GamepadButton.dpadUp, true));
    service.handleEvent(button(GamepadButton.dpadUp, false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(topFirst.hasPrimaryFocus, isTrue);

    // Down from the top bar must return into the panel.
    service.handleEvent(button(GamepadButton.dpadDown, true));
    service.handleEvent(button(GamepadButton.dpadDown, false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(panelFirst.hasPrimaryFocus, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('joystick right enters the episode side tab and left returns',
      (tester) async {
    // Mirrors the VideoPage/PlayerItem wiring: the episode side tab is a
    // sibling focus scope on the right, so the player hands focus over on
    // right and the tab hands it back on left at its own edge.
    final service = GamepadInputService(events: const Stream.empty());
    final panelScope = FocusScopeNode(debugLabel: 'Player controls');
    final sideTabScope = FocusScopeNode(debugLabel: 'Episode side tab');
    final panelFirst = FocusNode(debugLabel: 'panel first');
    final tabFirst = FocusNode(debugLabel: 'tab first');
    final tabSecond = FocusNode(debugLabel: 'tab second');
    addTearDown(() {
      panelScope.dispose();
      sideTabScope.dispose();
      panelFirst.dispose();
      tabFirst.dispose();
      tabSecond.dispose();
      service.reset();
    });

    Widget navScope({
      required FocusScopeNode node,
      required Widget child,
      required TraversalDirection exitDirection,
      required FocusScopeNode exitTarget,
    }) {
      return Actions(
        actions: <Type, Action<Intent>>{
          GamepadNavigateIntent: CallbackAction<GamepadNavigateIntent>(
            onInvoke: (intent) {
              final focused = FocusManager.instance.primaryFocus;
              final moved =
                  focused?.focusInDirection(intent.direction) ?? false;
              if (!moved && intent.direction == exitDirection) {
                focusFirstGamepadControl(exitTarget);
              }
              return null;
            },
          ),
        },
        child: FocusScope(node: node, child: child),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: GamepadNavigationScope(
          service: service,
          child: Scaffold(
            body: Row(
              children: [
                Expanded(
                  child: navScope(
                    node: panelScope,
                    exitDirection: TraversalDirection.right,
                    exitTarget: sideTabScope,
                    child: TextButton(
                      focusNode: panelFirst,
                      autofocus: true,
                      onPressed: () {},
                      child: const Text('panel first'),
                    ),
                  ),
                ),
                Expanded(
                  child: navScope(
                    node: sideTabScope,
                    exitDirection: TraversalDirection.left,
                    exitTarget: panelScope,
                    child: Column(
                      children: [
                        TextButton(
                          focusNode: tabFirst,
                          onPressed: () {},
                          child: const Text('episode one'),
                        ),
                        TextButton(
                          focusNode: tabSecond,
                          onPressed: () {},
                          child: const Text('episode two'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(panelFirst.hasPrimaryFocus, isTrue);

    // Right from the player reaches the episode list.
    service.handleEvent(button(GamepadButton.dpadRight, true));
    service.handleEvent(button(GamepadButton.dpadRight, false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tabFirst.hasPrimaryFocus, isTrue);

    // Left at the tab's edge returns to the player.
    service.handleEvent(button(GamepadButton.dpadLeft, true));
    service.handleEvent(button(GamepadButton.dpadLeft, false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(panelFirst.hasPrimaryFocus, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
