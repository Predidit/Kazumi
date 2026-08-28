import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/constants.dart';

typedef PlayerShortcutAction = FutureOr<void> Function();

class PlayerLongPressShortcutActions {
  const PlayerLongPressShortcutActions({
    required this.onRepeat,
    required this.onRelease,
  });

  final PlayerShortcutAction onRepeat;
  final PlayerShortcutAction onRelease;
}

/// Dispatches player shortcuts before focused controls handle the key event.
///
/// [focusScopeNode] must be attached to a stable ancestor of the player area.
/// Dialog routes and explicitly blocked overlay interactions keep their normal
/// key handling. Active long-press shortcuts are always released, even after
/// focus leaves the player or this widget is disposed.
///
/// Long-press shortcuts are driven by timers instead of relying on OS key
/// auto-repeat ([KeyRepeatEvent]). This keeps hold-to-repeat working with
/// synthetic key input (e.g. mouse-button remappers that only send a single
/// key down/up pair) and makes real-keyboard holding more responsive.
class PlayerKeyboardShortcuts extends StatefulWidget {
  const PlayerKeyboardShortcuts({
    super.key,
    required this.focusScopeNode,
    required this.actions,
    this.longPressActions = const <String, PlayerLongPressShortcutActions>{},
    this.isBlocked,
    this.shortcuts,
  });

  final FocusNode focusScopeNode;
  final Map<String, PlayerShortcutAction> actions;
  final Map<String, PlayerLongPressShortcutActions> longPressActions;
  final bool Function()? isBlocked;
  final Map<String, List<String>>? shortcuts;

  @override
  State<PlayerKeyboardShortcuts> createState() =>
      _PlayerKeyboardShortcutsState();
}

class _PlayerKeyboardShortcutsState extends State<PlayerKeyboardShortcuts> {
  /// Delay before a held key starts repeating, distinguishing a quick tap
  /// from a long press.
  static const Duration _longPressDelay = Duration(milliseconds: 250);

  /// Interval between repeat invocations while the long press is active.
  static const Duration _longPressRepeatInterval =
      Duration(milliseconds: 100);

  late Map<String, List<String>> _shortcuts;
  final Map<LogicalKeyboardKey, PlayerLongPressShortcutActions>
      _activeLongPressKeys =
      <LogicalKeyboardKey, PlayerLongPressShortcutActions>{};

  /// One-shot timers that arm the long-press repeat after [_longPressDelay].
  final Map<LogicalKeyboardKey, Timer> _longPressArmTimers =
      <LogicalKeyboardKey, Timer>{};

  /// Periodic timers driving [PlayerLongPressShortcutActions.onRepeat] while
  /// a long-press key stays held.
  final Map<LogicalKeyboardKey, Timer> _longPressRepeatTimers =
      <LogicalKeyboardKey, Timer>{};

  @override
  void initState() {
    super.initState();
    _shortcuts = widget.shortcuts ?? _loadShortcuts();
    FocusManager.instance.addEarlyKeyEventHandler(_handleKeyEvent);
  }

  @override
  void didUpdateWidget(PlayerKeyboardShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shortcuts != oldWidget.shortcuts) {
      _shortcuts = widget.shortcuts ?? _loadShortcuts();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleKeyEvent);
    _releaseAllLongPressShortcuts();
    super.dispose();
  }

  Map<String, List<String>> _loadShortcuts() {
    return <String, List<String>>{
      for (final entry in defaultShortcuts.entries)
        entry.key: GStorage.getStringListSettingByName(
          'shortcut_${entry.key}',
          defaultValue: entry.value,
        ),
    };
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is KeyUpEvent) {
      final longPressActions = _activeLongPressKeys.remove(event.logicalKey);
      if (longPressActions != null) {
        _cancelLongPressTimers(event.logicalKey);
        _invokeAction(longPressActions.onRelease);
        return KeyEventResult.handled;
      }
    }

    if (!_shouldHandleShortcut()) {
      return KeyEventResult.ignored;
    }

    final keyLabel = event.logicalKey.keyLabel.isNotEmpty
        ? event.logicalKey.keyLabel
        : event.logicalKey.debugName ?? '';
    final actionName = _findActionName(keyLabel);
    if (actionName == null) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      final action = widget.actions[actionName];
      if (action == null) {
        return KeyEventResult.ignored;
      }
      final longPressActions = widget.longPressActions[actionName];
      if (longPressActions != null) {
        _activeLongPressKeys[event.logicalKey] = longPressActions;
        _armLongPressRepeat(event.logicalKey, longPressActions);
      }
      _invokeAction(action);
      return KeyEventResult.handled;
    }

    if (event is KeyRepeatEvent) {
      final longPressActions = _activeLongPressKeys[event.logicalKey];
      // Already repeating through the timer, or no long press registered.
      if (longPressActions == null ||
          _longPressRepeatTimers.containsKey(event.logicalKey)) {
        return KeyEventResult.ignored;
      }
      // OS auto-repeat arrived before our arm timer fired: activate now.
      _activateLongPressRepeat(event.logicalKey, longPressActions);
      _invokeAction(longPressActions.onRepeat);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _armLongPressRepeat(
    LogicalKeyboardKey key,
    PlayerLongPressShortcutActions actions,
  ) {
    _longPressArmTimers[key]?.cancel();
    _longPressArmTimers[key] = Timer(_longPressDelay, () {
      _longPressArmTimers.remove(key);
      if (!_longPressRepeatTimers.containsKey(key)) {
        _activateLongPressRepeat(key, actions);
      }
    });
  }

  void _activateLongPressRepeat(
    LogicalKeyboardKey key,
    PlayerLongPressShortcutActions actions,
  ) {
    _longPressRepeatTimers[key]?.cancel();
    _invokeAction(actions.onRepeat);
    _longPressRepeatTimers[key] = Timer.periodic(
      _longPressRepeatInterval,
      (_) {
        if (!_activeLongPressKeys.containsKey(key)) {
          _cancelLongPressTimers(key);
          return;
        }
        _invokeAction(actions.onRepeat);
      },
    );
  }

  void _cancelLongPressTimers(LogicalKeyboardKey key) {
    _longPressArmTimers.remove(key)?.cancel();
    _longPressRepeatTimers.remove(key)?.cancel();
  }

  bool _shouldHandleShortcut() {
    if (widget.isBlocked?.call() ?? false) {
      return false;
    }

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return false;
    }

    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null ||
        (primaryFocus != widget.focusScopeNode &&
            !primaryFocus.ancestors.contains(widget.focusScopeNode))) {
      return false;
    }

    final focusContext = primaryFocus.context;
    if (focusContext == null) {
      return true;
    }
    return focusContext.widget is! EditableText &&
        focusContext.findAncestorWidgetOfExactType<EditableText>() == null;
  }

  String? _findActionName(String keyLabel) {
    for (final entry in _shortcuts.entries) {
      if (entry.value.contains(keyLabel)) {
        return entry.key;
      }
    }
    return null;
  }

  void _releaseAllLongPressShortcuts() {
    for (final key in _longPressArmTimers.keys.toList()) {
      _longPressArmTimers.remove(key)?.cancel();
    }
    for (final key in _longPressRepeatTimers.keys.toList()) {
      _longPressRepeatTimers.remove(key)?.cancel();
    }
    final actions = _activeLongPressKeys.values.toSet();
    _activeLongPressKeys.clear();
    for (final action in actions) {
      _invokeAction(action.onRelease);
    }
  }

  void _invokeAction(PlayerShortcutAction action) {
    unawaited(_runAction(action));
  }

  Future<void> _runAction(PlayerShortcutAction action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'player keyboard shortcuts',
          context: ErrorDescription('while invoking a player shortcut'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}