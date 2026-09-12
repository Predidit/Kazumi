import 'dart:async';
import 'dart:ui' show ViewFocusEvent, ViewFocusState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/services/platform/gamepad_input_service.dart';

class GamepadActivateIntent extends Intent {
  const GamepadActivateIntent();
}

class GamepadNavigateIntent extends Intent {
  const GamepadNavigateIntent(this.direction);

  final TraversalDirection direction;
}

class GamepadBackIntent extends Intent {
  const GamepadBackIntent();
}

class GamepadSecondaryActionIntent extends Intent {
  const GamepadSecondaryActionIntent();
}

class GamepadContextActionIntent extends Intent {
  const GamepadContextActionIntent();
}

class GamepadPreviousSectionIntent extends Intent {
  const GamepadPreviousSectionIntent();
}

class GamepadNextSectionIntent extends Intent {
  const GamepadNextSectionIntent();
}

class GamepadPreviousSecondarySectionIntent extends Intent {
  const GamepadPreviousSecondarySectionIntent();
}

class GamepadNextSecondarySectionIntent extends Intent {
  const GamepadNextSecondarySectionIntent();
}

class GamepadMenuIntent extends Intent {
  const GamepadMenuIntent();
}

class GamepadViewIntent extends Intent {
  const GamepadViewIntent();
}

class GamepadLeftStickClickIntent extends Intent {
  const GamepadLeftStickClickIntent();
}

class GamepadRightStickClickIntent extends Intent {
  const GamepadRightStickClickIntent();
}

class _GamepadServiceScope extends InheritedWidget {
  const _GamepadServiceScope({
    required this.service,
    required super.child,
  });

  final GamepadInputService service;

  @override
  bool updateShouldNotify(_GamepadServiceScope oldWidget) =>
      oldWidget.service != service;
}

/// Dispatches normalized gamepad commands from the current primary focus.
///
/// Feature widgets may override a command by registering its intent in an
/// [Actions] ancestor. Commands without a local action use standard Flutter
/// activation, spatial focus traversal, scrolling, and navigator dismissal.
class GamepadNavigationScope extends StatefulWidget {
  const GamepadNavigationScope({
    super.key,
    required this.service,
    required this.child,
  });

  final GamepadInputService service;
  final Widget child;

  /// Optional global fallback that switches the persistent menu/sidebar
  /// destination when no local action claims a shoulder-button press.
  ///
  /// The menu shell registers this so LB/RB keep controlling the sidebar even
  /// while a covering page (settings, player, ...) owns the focus. The player
  /// overloads the shoulder buttons for seeking, but its own action is found
  /// first from the player focus, so the fallback only fires where nothing
  /// else claims the command.
  static void Function(int offset)? onSectionFallback;

  static GamepadInputService? maybeServiceOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_GamepadServiceScope>()
        ?.service;
  }

  @override
  State<GamepadNavigationScope> createState() => _GamepadNavigationScopeState();
}

class _GamepadNavigationScopeState extends State<GamepadNavigationScope>
    with WidgetsBindingObserver {
  StreamSubscription<GamepadCommandEvent>? _subscription;
  bool _focusRecoveryScheduled = false;
  bool _appActive = true;
  bool _viewFocused = true;

  final Set<LogicalKeyboardKey> _handledNavigationKeys = <LogicalKeyboardKey>{};
  final Map<LogicalKeyboardKey, Timer> _keyboardActionTimers =
      <LogicalKeyboardKey, Timer>{};
  final Map<LogicalKeyboardKey, GamepadCommand> _keyboardActions =
      <LogicalKeyboardKey, GamepadCommand>{};
  final Set<LogicalKeyboardKey> _pressedKeyboardActionKeys =
      <LogicalKeyboardKey>{};
  final Map<GamepadCommand, Timer> _nativeFaceButtonSuppression =
      <GamepadCommand, Timer>{};

  static const Duration _keyboardActionGrace = Duration(milliseconds: 90);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.service.setSuspended(!_appActive || !_viewFocused);
    widget.service.start();
    _subscription = widget.service.commands.listen(_dispatch);
    HardwareKeyboard.instance.addHandler(_observeKeyRelease);
    FocusManager.instance.addListener(_scheduleFocusRecovery);
    topRouteRevision.addListener(_retargetFocusAfterRouteChange);
  }

  @override
  void didUpdateWidget(GamepadNavigationScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service == widget.service) {
      return;
    }
    _clearPendingInput(oldWidget.service);
    unawaited(_subscription?.cancel());
    widget.service.setSuspended(!_appActive || !_viewFocused);
    widget.service.start();
    _subscription = widget.service.commands.listen(_dispatch);
  }

  void _clearPendingInput(GamepadInputService service) {
    service.reset();
    _handledNavigationKeys.clear();
    for (final timer in _keyboardActionTimers.values) {
      timer.cancel();
    }
    for (final timer in _nativeFaceButtonSuppression.values) {
      timer.cancel();
    }
    _keyboardActionTimers.clear();
    _nativeFaceButtonSuppression.clear();
    _keyboardActions.clear();
    _pressedKeyboardActionKeys.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _updateSuspension();
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (event.viewId != View.of(context).viewId) return;
    _viewFocused = event.state == ViewFocusState.focused;
    _updateSuspension();
  }

  void _updateSuspension() {
    _clearPendingInput(widget.service);
    widget.service.setSuspended(!_appActive || !_viewFocused);
  }

  // Observe releases even when the new focused widget consumes the event.
  bool _observeKeyRelease(KeyEvent event) {
    if (event is KeyUpEvent &&
        _handledNavigationKeys.remove(event.logicalKey)) {
      final command = _navigationCommandForKey(event.logicalKey);
      if (command != null) {
        widget.service.handleKeyboardNavigation(command, false);
      }
    }
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_observeKeyRelease);
    FocusManager.instance.removeListener(_scheduleFocusRecovery);
    topRouteRevision.removeListener(_retargetFocusAfterRouteChange);
    _clearPendingInput(widget.service);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _dispatch(GamepadCommandEvent event) {
    if (!mounted) {
      return;
    }
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    _suppressKeyboardFaceAction(event.command);
    final primary = FocusManager.instance.primaryFocus;
    if ((primary == null || !isGamepadFocusUsable(primary)) &&
        event.command != GamepadCommand.back) {
      _focusTopRoute(currentTopRoute.value);
      return;
    }
    final direction = switch (event.command) {
      GamepadCommand.navigateUp => TraversalDirection.up,
      GamepadCommand.navigateDown => TraversalDirection.down,
      GamepadCommand.navigateLeft => TraversalDirection.left,
      GamepadCommand.navigateRight => TraversalDirection.right,
      _ => null,
    };
    if (direction != null) {
      final intent = GamepadNavigateIntent(direction);
      if (!_invokeLocal(intent) && !invokeGamepadControlDirection(direction)) {
        final focus = FocusManager.instance.primaryFocus;
        if (focus == null || focus is FocusScopeNode) {
          _focusTopRoute(currentTopRoute.value);
        } else {
          focus.focusInDirection(direction);
        }
      }
      _ensurePrimaryFocusVisible();
      return;
    }

    switch (event.command) {
      case GamepadCommand.activate:
        if (!_invokeLocal(const GamepadActivateIntent())) {
          _invokeStandard(const ActivateIntent());
        }
      case GamepadCommand.back:
        final focusContext = FocusManager.instance.primaryFocus?.context;
        final menuController =
            focusContext == null ? null : MenuController.maybeOf(focusContext);
        if (menuController?.isOpen ?? false) {
          menuController!.close();
        } else if (!_invokeLocal(const GamepadBackIntent())) {
          unawaited(_popFromFocusedNavigator(focusContext));
        }
      case GamepadCommand.secondaryAction:
        _invokeLocal(const GamepadSecondaryActionIntent());
      case GamepadCommand.contextAction:
        _invokeLocal(const GamepadContextActionIntent());
      case GamepadCommand.previousSection:
        if (!_invokeLocal(const GamepadPreviousSectionIntent())) {
          _switchSectionFallback(-1);
        }
      case GamepadCommand.nextSection:
        if (!_invokeLocal(const GamepadNextSectionIntent())) {
          _switchSectionFallback(1);
        }
      case GamepadCommand.previousSecondarySection:
        _invokeLocal(const GamepadPreviousSecondarySectionIntent());
      case GamepadCommand.nextSecondarySection:
        _invokeLocal(const GamepadNextSecondarySectionIntent());
      case GamepadCommand.menu:
        _invokeLocal(const GamepadMenuIntent());
      case GamepadCommand.view:
        _invokeLocal(const GamepadViewIntent());
      case GamepadCommand.leftStickClick:
        _invokeLocal(const GamepadLeftStickClickIntent());
      case GamepadCommand.rightStickClick:
        _invokeLocal(const GamepadRightStickClickIntent());
      case GamepadCommand.scrollUp:
        _invokeStandard(const ScrollIntent(direction: AxisDirection.up));
      case GamepadCommand.scrollDown:
        _invokeStandard(const ScrollIntent(direction: AxisDirection.down));
      case GamepadCommand.scrollLeft:
        _invokeStandard(const ScrollIntent(direction: AxisDirection.left));
      case GamepadCommand.scrollRight:
        _invokeStandard(const ScrollIntent(direction: AxisDirection.right));
      case GamepadCommand.navigateUp:
      case GamepadCommand.navigateDown:
      case GamepadCommand.navigateLeft:
      case GamepadCommand.navigateRight:
        break;
    }
  }

  /// Handheld middleware can report a face-button press through both the
  /// gamepad event channel and a virtual keyboard. Native face-button events
  /// are authoritative, so suppress the matching keyboard fallback briefly.
  /// In particular, a virtual Enter generated by B must never activate focus.
  void _suppressKeyboardFaceAction(GamepadCommand command) {
    final commands = switch (command) {
      GamepadCommand.back => const <GamepadCommand>[
          GamepadCommand.activate,
          GamepadCommand.back,
        ],
      GamepadCommand.activate => const <GamepadCommand>[
          GamepadCommand.activate,
        ],
      _ => const <GamepadCommand>[],
    };
    for (final suppressed in commands) {
      _cancelKeyboardAction(suppressed);
      _nativeFaceButtonSuppression.remove(suppressed)?.cancel();
      _nativeFaceButtonSuppression[suppressed] = Timer(
        _keyboardActionGrace,
        () => _nativeFaceButtonSuppression.remove(suppressed)?.cancel(),
      );
    }
  }

  void _cancelKeyboardAction(GamepadCommand command) {
    final keys = _keyboardActions.entries
        .where((entry) => entry.value == command)
        .map((entry) => entry.key)
        .toList();
    for (final key in keys) {
      _keyboardActionTimers.remove(key)?.cancel();
      _keyboardActions.remove(key);
    }
  }

  bool _isNativeFaceActionSuppressed(GamepadCommand command) =>
      _nativeFaceButtonSuppression[command] != null;

  Future<void> _popFromFocusedNavigator(BuildContext? focusContext) async {
    final focusedNavigator =
        focusContext == null ? null : Navigator.maybeOf(focusContext);
    final rootNavigator = rootNavigatorKey.currentState;
    if (focusedNavigator != null && focusedNavigator != rootNavigator) {
      if (await focusedNavigator.maybePop()) {
        return;
      }
    }
    await rootNavigator?.maybePop();
  }

  bool _invokeLocal<T extends Intent>(T intent) {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    final action = Actions.maybeFind<T>(focusContext);
    if (action == null || !action.isEnabled(intent)) return false;
    Actions.invoke(focusContext, intent);
    return true;
  }

  void _invokeStandard<T extends Intent>(T intent) {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null) {
      Actions.maybeInvoke(focusContext, intent);
    }
  }

  /// Shoulder-button fallback: nothing in the current page claimed the
  /// command, so the persistent sidebar takes over, matching wiliwili where
  /// L1/R1 always switch the top-level destinations.
  ///
  /// Gated on the top route being a full page: inside a dialog or bottom
  /// sheet the buttons must not yank the underlying page around.
  void _switchSectionFallback(int offset) {
    final fallback = GamepadNavigationScope.onSectionFallback;
    if (fallback == null) {
      return;
    }
    if (currentTopRoute.value is! PageRoute) {
      return;
    }
    fallback(offset);
  }

  void _scheduleFocusRecovery() {
    if (!mounted ||
        _focusRecoveryScheduled ||
        !widget.service.usingGamepad.value) {
      return;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && isGamepadFocusUsable(primary)) return;
    _focusRecoveryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusRecoveryScheduled = false;
      if (!mounted || !widget.service.usingGamepad.value) return;
      final primary = FocusManager.instance.primaryFocus;
      if (primary != null && isGamepadFocusUsable(primary)) return;
      if (primary is FocusScopeNode && focusFirstGamepadControl(primary)) {
        return;
      }
      _focusTopRoute(currentTopRoute.value);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _retargetFocusAfterRouteChange() {
    if (!mounted) return;
    _clearPendingInput(widget.service);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final primary = FocusManager.instance.primaryFocus;
      // A nested route is valid when its ancestors are current too; comparing
      // its identity with the root route incorrectly steals settings focus.
      if (primary == null || !isGamepadFocusUsable(primary)) {
        _focusTopRoute(currentTopRoute.value);
      }
    });
  }

  bool _focusTopRoute(Route<dynamic>? route) {
    final routeContext = route is ModalRoute ? route.subtreeContext : null;
    final focusContext =
        routeContext?.mounted == true ? routeContext! : context;
    return focusFirstGamepadControl(FocusScope.of(focusContext));
  }

  void _ensurePrimaryFocusVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focusContext = FocusManager.instance.primaryFocus?.context;
      if (!mounted || focusContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        focusContext,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  void _markPointerInput() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    _clearPendingInput(widget.service);
    widget.service.markPointerInput();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final command = _navigationCommandForKey(event.logicalKey);
    if (command != null && widget.service.enabled) {
      if (event is KeyUpEvent) {
        if (!_handledNavigationKeys.remove(event.logicalKey)) {
          return KeyEventResult.ignored;
        }
        widget.service.handleKeyboardNavigation(command, false);
        return KeyEventResult.handled;
      }
      if (_focusedEditable() != null) {
        return KeyEventResult.ignored;
      }
      if (event is KeyRepeatEvent &&
          !_handledNavigationKeys.contains(event.logicalKey)) {
        return KeyEventResult.handled;
      }
      _handledNavigationKeys.add(event.logicalKey);
      widget.service.handleKeyboardNavigation(command, true);
      return KeyEventResult.handled;
    }
    if (!widget.service.enabled) {
      return KeyEventResult.ignored;
    }

    if (_focusedEditable() != null &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.space)) {
      return KeyEventResult.ignored;
    }

    final keyboardCommand = _keyboardCommandForKey(event.logicalKey);
    if (keyboardCommand == null) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) {
      final wasPressed = _pressedKeyboardActionKeys.remove(event.logicalKey);
      return wasPressed || _isNativeFaceActionSuppressed(keyboardCommand)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (_isNativeFaceActionSuppressed(keyboardCommand)) {
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent ||
        _pressedKeyboardActionKeys.contains(event.logicalKey)) {
      return KeyEventResult.handled;
    }

    _pressedKeyboardActionKeys.add(event.logicalKey);
    _keyboardActions[event.logicalKey] = keyboardCommand;
    _keyboardActionTimers[event.logicalKey] = Timer(_keyboardActionGrace, () {
      _keyboardActionTimers.remove(event.logicalKey);
      final pending = _keyboardActions.remove(event.logicalKey);
      if (pending == null || _isNativeFaceActionSuppressed(pending)) {
        return;
      }
      switch (event.logicalKey) {
        case LogicalKeyboardKey.enter:
        case LogicalKeyboardKey.numpadEnter:
        case LogicalKeyboardKey.space:
          _invokeStandard(const ActivateIntent());
        case LogicalKeyboardKey.escape:
          _invokeStandard(const DismissIntent());
        case LogicalKeyboardKey.gameButtonA:
        case LogicalKeyboardKey.gameButtonB:
          _dispatch(GamepadCommandEvent(command: pending, gamepadId: -1));
      }
    });
    return KeyEventResult.handled;
  }

  GamepadCommand? _navigationCommandForKey(LogicalKeyboardKey key) {
    return switch (key) {
      LogicalKeyboardKey.arrowUp => GamepadCommand.navigateUp,
      LogicalKeyboardKey.arrowDown => GamepadCommand.navigateDown,
      LogicalKeyboardKey.arrowLeft => GamepadCommand.navigateLeft,
      LogicalKeyboardKey.arrowRight => GamepadCommand.navigateRight,
      _ => null,
    };
  }

  GamepadCommand? _keyboardCommandForKey(LogicalKeyboardKey key) {
    return switch (key) {
      LogicalKeyboardKey.enter => GamepadCommand.activate,
      LogicalKeyboardKey.numpadEnter => GamepadCommand.activate,
      LogicalKeyboardKey.space => GamepadCommand.activate,
      LogicalKeyboardKey.escape => GamepadCommand.back,
      LogicalKeyboardKey.gameButtonA => GamepadCommand.activate,
      LogicalKeyboardKey.gameButtonB => GamepadCommand.back,
      _ => null,
    };
  }

  // Keep text editing keys in Flutter's input pipeline.
  EditableTextState? _focusedEditable() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) {
      return null;
    }
    EditableTextState? found;
    bool inspect(Element element) {
      if (element is StatefulElement && element.state is EditableTextState) {
        found = element.state as EditableTextState;
        return true;
      }
      return false;
    }

    void visit(Element element) {
      if (found != null) {
        return;
      }
      if (inspect(element)) {
        return;
      }
      element.visitChildren(visit);
    }

    if (context is Element) {
      inspect(context);
      context.visitAncestorElements((element) => !inspect(element));
      if (found == null) {
        // Some custom editable widgets attach their FocusNode above the
        // EditableText rather than inside it.
        context.visitChildren(visit);
      }
    }
    return found;
  }

  @override
  Widget build(BuildContext context) {
    return _GamepadServiceScope(
      service: widget.service,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _handleKeyEvent,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _markPointerInput(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: widget.service.usingGamepad,
                child: widget.child,
                builder: (context, usingGamepad, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    navigationMode: usingGamepad
                        ? NavigationMode.directional
                        : NavigationMode.traditional,
                  ),
                  child: child!,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Flutter's offstage routes can retain nodes; only navigate visible routes.
bool isGamepadFocusUsable(FocusNode node) {
  final context = node.context;
  if (context == null ||
      !node.canRequestFocus ||
      node is FocusScopeNode ||
      node.skipTraversal) {
    return false;
  }
  bool visible = ModalRoute.of(context)?.isCurrent ?? true;
  context.visitAncestorElements((element) {
    if (element.widget is Offstage && (element.widget as Offstage).offstage) {
      visible = false;
    }
    return visible;
  });
  for (final ancestor in node.ancestors) {
    final ancestorContext = ancestor.context;
    if (ancestorContext != null &&
        ModalRoute.of(ancestorContext)?.isCurrent == false) {
      return false;
    }
  }
  return visible;
}

bool focusFirstGamepadControl(FocusNode scope) {
  final remembered = scope is FocusScopeNode ? scope.focusedChild : null;
  if (remembered != null && isGamepadFocusUsable(remembered)) {
    remembered.requestFocus();
    return true;
  }
  for (final node in scope.traversalDescendants) {
    if (isGamepadFocusUsable(node)) {
      node.requestFocus();
      return true;
    }
  }
  return false;
}

/// Whether the current primary focus is inside an editable text field.
///
/// Directional traversal must not be swallowed by text-editing shortcuts or a
/// focused text field becomes a dead end for the joystick.
bool primaryFocusIsEditable() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  if (context.widget is EditableText) return true;
  if (context.findAncestorWidgetOfExactType<EditableText>() != null) {
    return true;
  }
  if (context is! Element) return false;
  bool found = false;
  void visit(Element element) {
    if (found) return;
    if (element is StatefulElement && element.state is EditableTextState) {
      found = true;
      return;
    }
    element.visitChildren(visit);
  }

  context.visitChildren(visit);
  return found;
}

/// Reuse the focused control's arrow action (slider, text field, etc.) without
/// synthesizing key events or accidentally invoking default focus traversal.
bool invokeGamepadControlDirection(TraversalDirection direction) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  // Text fields own the arrow keys for cursor movement; let the caller fall
  // back to focus traversal so the stick can always leave the field.
  if (primaryFocusIsEditable()) return false;
  final key = switch (direction) {
    TraversalDirection.up => LogicalKeyboardKey.arrowUp,
    TraversalDirection.down => LogicalKeyboardKey.arrowDown,
    TraversalDirection.left => LogicalKeyboardKey.arrowLeft,
    TraversalDirection.right => LogicalKeyboardKey.arrowRight,
  };
  bool handled = false;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is! Shortcuts) return true;
    for (final entry in widget.shortcuts.entries) {
      final activator = entry.key;
      final matches = activator is SingleActivator &&
          activator.trigger == key &&
          !activator.control &&
          !activator.shift &&
          !activator.alt &&
          !activator.meta;
      if (!matches) continue;
      final intent = entry.value;
      if (intent is DirectionalFocusIntent) return false;
      final action = Actions.maybeFind<Intent>(context, intent: intent);
      if (action != null && action.isEnabled(intent)) {
        Actions.invoke(context, intent);
        handled = true;
      }
      return false;
    }
    return true;
  });
  return handled;
}
