import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/services/platform/tv_mode.dart';

typedef PlayerShortcutAction = FutureOr<void> Function();
typedef PlayerNavigationKeyHandler = bool Function(LogicalKeyboardKey key);

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
class PlayerKeyboardShortcuts extends StatefulWidget {
  const PlayerKeyboardShortcuts({
    super.key,
    required this.focusScopeNode,
    required this.actions,
    this.longPressActions = const <String, PlayerLongPressShortcutActions>{},
    this.isBlocked,
    this.shouldHandleAction,
    this.onNavigationKey,
    this.shortcuts,
  });

  final FocusNode focusScopeNode;
  final Map<String, PlayerShortcutAction> actions;
  final Map<String, PlayerLongPressShortcutActions> longPressActions;
  final bool Function()? isBlocked;
  final bool Function(String actionName, LogicalKeyboardKey key)?
      shouldHandleAction;
  final PlayerNavigationKeyHandler? onNavigationKey;
  final Map<String, List<String>>? shortcuts;

  @override
  State<PlayerKeyboardShortcuts> createState() =>
      _PlayerKeyboardShortcutsState();
}

class _PlayerKeyboardShortcutsState extends State<PlayerKeyboardShortcuts> {
  static const _tvRemoteChannel = MethodChannel(
    'com.predidit.kazumi/tv_remote',
  );
  late Map<String, List<String>> _shortcuts;
  final Map<LogicalKeyboardKey, PlayerLongPressShortcutActions>
      _activeLongPressKeys =
      <LogicalKeyboardKey, PlayerLongPressShortcutActions>{};

  @override
  void initState() {
    super.initState();
    _shortcuts = widget.shortcuts ?? _loadShortcuts();
    FocusManager.instance.addEarlyKeyEventHandler(_handleKeyEvent);
    if (TvMode.enabled) {
      _tvRemoteChannel.setMethodCallHandler(_handleTvRemoteMethod);
      unawaited(_tvRemoteChannel.invokeMethod<void>(
        'setPlayerActive',
        const {'active': true},
      ));
    }
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
    if (TvMode.enabled) {
      _tvRemoteChannel.setMethodCallHandler(null);
      unawaited(_tvRemoteChannel.invokeMethod<void>(
        'setPlayerActive',
        const {'active': false},
      ));
    }
    _releaseAllLongPressShortcuts();
    super.dispose();
  }

  Future<void> _handleTvRemoteMethod(MethodCall call) async {
    if (call.method != 'dispatch' || call.arguments is! String) return;
    final actionName = call.arguments as String;
    if (widget.isBlocked?.call() ?? false) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final action = widget.actions[actionName];
    if (action != null) await _runAction(action);
  }

  Map<String, List<String>> _loadShortcuts() {
    final shortcuts = <String, List<String>>{
      for (final entry in defaultShortcuts.entries)
        entry.key: GStorage.getStringListSettingByName(
          'shortcut_${entry.key}',
          defaultValue: entry.value,
        ),
    };
    return TvMode.enabled ? withTvRemoteShortcuts(shortcuts) : shortcuts;
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is KeyUpEvent) {
      final longPressActions = _activeLongPressKeys.remove(event.logicalKey);
      if (longPressActions != null) {
        _invokeAction(longPressActions.onRelease);
        return KeyEventResult.handled;
      }
    }

    if (!_shouldHandleShortcut()) {
      return KeyEventResult.ignored;
    }

    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        (widget.onNavigationKey?.call(event.logicalKey) ?? false)) {
      return KeyEventResult.handled;
    }

    final keyLabel = event.logicalKey.keyLabel.isNotEmpty
        ? event.logicalKey.keyLabel
        : event.logicalKey.debugName ?? '';
    final actionName = _findActionName(keyLabel);
    if (actionName == null) {
      return KeyEventResult.ignored;
    }
    if (!(widget.shouldHandleAction?.call(actionName, event.logicalKey) ??
        true)) {
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
      }
      _invokeAction(action);
      return KeyEventResult.handled;
    }

    if (event is KeyRepeatEvent) {
      final longPressActions = _activeLongPressKeys[event.logicalKey];
      if (longPressActions == null) {
        return KeyEventResult.ignored;
      }
      _invokeAction(longPressActions.onRepeat);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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

/// Adds Android TV remote aliases without changing the user's stored mapping.
Map<String, List<String>> withTvRemoteShortcuts(
  Map<String, List<String>> source,
) {
  final result = <String, List<String>>{
    for (final entry in source.entries) entry.key: [...entry.value],
  };

  String label(LogicalKeyboardKey key) => key.keyLabel.isNotEmpty
      ? key.keyLabel
      : key.debugName ?? key.keyId.toString();

  void add(String action, LogicalKeyboardKey key) {
    final values = result.putIfAbsent(action, () => <String>[]);
    final keyLabel = label(key);
    if (!values.contains(keyLabel)) values.add(keyLabel);
  }

  result['volumeup']?.remove(label(LogicalKeyboardKey.arrowUp));
  result['volumedown']?.remove(label(LogicalKeyboardKey.arrowDown));
  result['exitfullscreen']?.remove(label(LogicalKeyboardKey.escape));

  for (final key in [
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.gameButtonA,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
  ]) {
    add('showcontrols', key);
  }
  add('playorpause', LogicalKeyboardKey.mediaPlayPause);
  add('play', LogicalKeyboardKey.mediaPlay);
  add('pause', LogicalKeyboardKey.mediaPause);
  add('forward', LogicalKeyboardKey.mediaFastForward);
  add('forward', LogicalKeyboardKey.mediaSkipForward);
  add('rewind', LogicalKeyboardKey.mediaRewind);
  add('rewind', LogicalKeyboardKey.mediaSkipBackward);
  add('next', LogicalKeyboardKey.mediaTrackNext);
  add('next', LogicalKeyboardKey.channelUp);
  add('prev', LogicalKeyboardKey.mediaTrackPrevious);
  add('prev', LogicalKeyboardKey.channelDown);
  add('prev', LogicalKeyboardKey.mediaLast);
  add('volumeup', LogicalKeyboardKey.audioVolumeUp);
  add('volumedown', LogicalKeyboardKey.audioVolumeDown);
  add('togglemute', LogicalKeyboardKey.audioVolumeMute);
  add('showepisodes', LogicalKeyboardKey.guide);
  add('showepisodes', LogicalKeyboardKey.mediaTopMenu);
  add('showepisodes', LogicalKeyboardKey.colorF2Yellow);
  add('toggledanmaku', LogicalKeyboardKey.closedCaptionToggle);
  add('toggledanmaku', LogicalKeyboardKey.mediaAudioTrack);
  add('toggledanmaku', LogicalKeyboardKey.colorF0Red);
  add('togglefavorite', LogicalKeyboardKey.browserFavorites);
  add('togglefavorite', LogicalKeyboardKey.favoriteStore0);
  add('togglefavorite', LogicalKeyboardKey.colorF1Green);
  add('showdetails', LogicalKeyboardKey.info);
  add('showdetails', LogicalKeyboardKey.colorF3Blue);
  add('showremotehelp', LogicalKeyboardKey.help);
  add('showremotehelp', LogicalKeyboardKey.contextMenu);
  add('showremotehelp', LogicalKeyboardKey.f1);
  add('back', LogicalKeyboardKey.goBack);
  add('back', LogicalKeyboardKey.escape);
  add('back', LogicalKeyboardKey.gameButtonB);
  add('exitplayer', LogicalKeyboardKey.exit);
  add('exitplayer', LogicalKeyboardKey.close);
  add('exitplayer', LogicalKeyboardKey.mediaClose);
  add('exitplayer', LogicalKeyboardKey.mediaStop);
  return result;
}

bool shouldDeferTvKeyToPlatform(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.audioVolumeUp ||
      key == LogicalKeyboardKey.audioVolumeDown ||
      key == LogicalKeyboardKey.audioVolumeMute;
}
