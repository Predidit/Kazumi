import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:universal_gamepad/universal_gamepad.dart';

enum GamepadCommand {
  navigateUp,
  navigateDown,
  navigateLeft,
  navigateRight,
  activate,
  back,
  secondaryAction,
  contextAction,
  previousSection,
  nextSection,
  previousSecondarySection,
  nextSecondarySection,
  menu,
  view,
  leftStickClick,
  rightStickClick,
  scrollUp,
  scrollDown,
  scrollLeft,
  scrollRight,
}

class GamepadCommandEvent {
  const GamepadCommandEvent({
    required this.command,
    required this.gamepadId,
    this.isRepeat = false,
  });

  final GamepadCommand command;
  final int gamepadId;
  final bool isRepeat;
}

enum _InputControl { leftStick, rightStick, keyboard }

typedef _CommandSource = ({int gamepadId, Object control});

/// Normalizes controller buttons and axes into stable application commands.
///
/// Button labels are deliberately semantic: [GamepadButton.a] means the south
/// face button, not a letter printed on a particular controller.
///
/// Input from every connected controller is merged into a single logical pad,
/// the same model borealis/wiliwili use. This matters on handhelds where one
/// physical stick is exposed through several kernel nodes at once (a native
/// node, an xpad compatibility node, and virtual pads from Handheld Daemon or
/// Steam Input). Treating those as separate controllers makes one flick emit
/// several navigation steps. Merging by command means duplicated nodes collapse
/// into one press.
///
/// A command is emitted only on the rising edge of that merged state, so
/// holding a stick past the dead zone moves focus once. Repetition is owned by
/// the app: [initialRepeatDelay] then [repeatInterval].
class GamepadInputService {
  GamepadInputService({
    Stream<GamepadEvent>? events,
    bool enabled = true,
    double stickDeadZone = 0.5,
    Duration initialRepeatDelay = const Duration(milliseconds: 250),
    Duration repeatInterval = const Duration(milliseconds: 100),
    Duration duplicateWindow = const Duration(milliseconds: 60),
    Duration keyboardHoldTimeout = const Duration(seconds: 2),
  })  : _events = events ??
            (enabled
                ? Gamepad.instance.events
                : const Stream<GamepadEvent>.empty()),
        // 测试依赖极端值：duplicateWindow=0 关闭去重、20ms 看门狗、
        // 10ms 重复节拍、1h 禁用重复。此处仅回落非法值（负数/超大），
        // 生产侧范围由设置页钳制（死区 0.15~0.75，延迟 50~2000ms）。
        _duplicateWindow = _sanitizeDuration(
          duplicateWindow,
          fallback: const Duration(milliseconds: 60),
          allowZero: true,
        ),
        _keyboardHoldTimeout = _sanitizeDuration(
          keyboardHoldTimeout,
          fallback: const Duration(seconds: 2),
        ),
        _enabled = enabled,
        _stickDeadZone = _sanitizeDeadZone(stickDeadZone),
        _initialRepeatDelay = _sanitizeDuration(
          initialRepeatDelay,
          fallback: const Duration(milliseconds: 250),
        ),
        _repeatInterval = _sanitizeDuration(
          repeatInterval,
          fallback: const Duration(milliseconds: 100),
        );

  static double _sanitizeDeadZone(double value) {
    if (!value.isFinite) {
      return 0.5;
    }
    return value.clamp(0.15, 0.75).toDouble();
  }

  static Duration _sanitizeDuration(
    Duration value, {
    required Duration fallback,
    bool allowZero = false,
    Duration? min,
    Duration? max,
  }) {
    // 仅防御非法值（非正/超大）：测试会传入 Duration.zero（关闭去重）、
    // 20ms 看门狗、10ms 重复节拍、1h 禁用重复，必须原样保留。
    if (value == Duration.zero && allowZero) {
      return value;
    }
    if (value <= Duration.zero || value > const Duration(days: 1)) {
      return fallback;
    }
    if (min != null && value < min) {
      return min;
    }
    if (max != null && value > max) {
      return max;
    }
    return value;
  }

  final Stream<GamepadEvent> _events;
  final StreamController<GamepadCommandEvent> _commands =
      StreamController<GamepadCommandEvent>.broadcast(sync: true);

  /// Latest axis values per controller. Kept per controller so a stick resting
  /// at centre on one pad cannot cancel a real deflection on another.
  final Map<int, Map<GamepadAxis, double>> _axes =
      <int, Map<GamepadAxis, double>>{};

  /// Which controls currently assert each command. Axis, D-pad, keyboard, and
  /// every controller are ORed into one held state before edges are emitted,
  /// matching Borealis' unified controller state.
  final Map<GamepadCommand, Set<_CommandSource>> _activeSources =
      <GamepadCommand, Set<_CommandSource>>{};
  final Map<GamepadCommand, Timer> _repeatTimers = <GamepadCommand, Timer>{};

  final ValueNotifier<bool> usingGamepad = ValueNotifier<bool>(false);

  StreamSubscription<GamepadEvent>? _subscription;
  bool _enabled;
  bool _suspended = false;
  int _generation = 0;
  double _stickDeadZone;
  Duration _initialRepeatDelay;
  Duration _repeatInterval;
  final Duration _duplicateWindow;

  /// A lost KeyUp must not leave a virtual D-pad direction held forever.
  /// Handheld middleware normally sends repeats while a key is held, so this
  /// watchdog is refreshed by every repeat and only releases silent input.
  final Duration _keyboardHoldTimeout;
  final Map<GamepadCommand, Timer> _keyboardNavigationWatchdogs =
      <GamepadCommand, Timer>{};

  /// When each command last fired a fresh (non-repeat) press.
  ///
  /// One physical stick exposed through several kernel nodes does not report
  /// those nodes in lockstep: node A can cross the threshold and fall back to
  /// centre before node B crosses it at all. Command-level merging alone still
  /// sees two complete press/release cycles there, which is what made a single
  /// flick move focus twice. Collapsing presses that land within this window
  /// treats them as the one physical action they are.
  final Map<GamepadCommand, Stopwatch> _lastPress =
      <GamepadCommand, Stopwatch>{};

  Stream<GamepadCommandEvent> get commands => _commands.stream;
  bool get enabled => _enabled;

  /// Stops registration-started native input work on unsupported platforms.
  static Future<void> disableNativeBackend() async {
    try {
      await Gamepad.instance.dispose();
    } catch (_) {}
  }

  /// Release threshold sits below the press threshold so a stick hovering near
  /// the dead zone cannot chatter between pressed and released.
  double get _stickReleaseThreshold => math.max(0.15, _stickDeadZone - 0.15);

  static const Set<GamepadCommand> _repeatableCommands = <GamepadCommand>{
    GamepadCommand.navigateUp,
    GamepadCommand.navigateDown,
    GamepadCommand.navigateLeft,
    GamepadCommand.navigateRight,
    GamepadCommand.previousSecondarySection,
    GamepadCommand.nextSecondarySection,
    GamepadCommand.scrollUp,
    GamepadCommand.scrollDown,
    GamepadCommand.scrollLeft,
    GamepadCommand.scrollRight,
  };

  static const Set<GamepadCommand> _navigationCommands = <GamepadCommand>{
    GamepadCommand.navigateUp,
    GamepadCommand.navigateDown,
    GamepadCommand.navigateLeft,
    GamepadCommand.navigateRight,
  };

  void start() {
    if (_subscription != null || _disposed) {
      return;
    }
    try {
      _subscription = _events.listen(
        handleEvent,
        onError: (Object _, StackTrace __) => reset(),
        onDone: reset,
        cancelOnError: false,
      );
    } catch (_) {
      _subscription = null;
    }
  }

  void configure({
    bool? enabled,
    double? stickDeadZone,
    Duration? initialRepeatDelay,
    Duration? repeatInterval,
  }) {
    final nextEnabled = enabled ?? _enabled;
    final nextDeadZone = stickDeadZone == null
        ? _stickDeadZone
        : _sanitizeDeadZone(stickDeadZone);
    // configure 同样仅回落非法值，保留测试极端值；UI 侧已钳制生产范围。
    final nextInitialDelay = initialRepeatDelay == null
        ? _initialRepeatDelay
        : _sanitizeDuration(
            initialRepeatDelay,
            fallback: _initialRepeatDelay,
          );
    final nextRepeatInterval = repeatInterval == null
        ? _repeatInterval
        : _sanitizeDuration(
            repeatInterval,
            fallback: _repeatInterval,
          );
    final thresholdsChanged = nextDeadZone != _stickDeadZone;
    final timingChanged = nextInitialDelay != _initialRepeatDelay ||
        nextRepeatInterval != _repeatInterval;

    _enabled = nextEnabled;
    _stickDeadZone = nextDeadZone;
    _initialRepeatDelay = nextInitialDelay;
    _repeatInterval = nextRepeatInterval;
    if (!_enabled || thresholdsChanged || timingChanged) {
      reset();
    }
  }

  void markPointerInput() {
    // A touch/click is an explicit hand-off from the controller. Clearing
    // held sources here prevents a stale virtual arrow from resuming after a
    // pointer-driven page change.
    reset();
    if (_disposed) {
      return;
    }
    try {
      usingGamepad.value = false;
    } catch (_) {
      // 已 dispose 后忽略：reset 已清理悬挂状态。
    }
  }

  /// Feeds desktop arrow keys into the same held state as controller input.
  ///
  /// Handheld middleware can expose one stick as both a gamepad axis and a
  /// virtual keyboard arrow. Keeping Flutter's default arrow traversal separate
  /// would move focus once for each path.
  void handleKeyboardNavigation(GamepadCommand command, bool pressed) {
    if (_disposed ||
        !_enabled ||
        _suspended ||
        !_navigationCommands.contains(command)) {
      return;
    }
    const source = (gamepadId: -1, control: _InputControl.keyboard);
    if (!pressed) {
      _keyboardNavigationWatchdogs.remove(command)?.cancel();
      _setSourceActive(source, command, false);
      return;
    }
    final generation = _generation;
    _setSourceActive(source, command, true);
    if (generation != _generation) return;
    _keyboardNavigationWatchdogs.remove(command)?.cancel();
    _keyboardNavigationWatchdogs[command] = Timer(_keyboardHoldTimeout, () {
      _keyboardNavigationWatchdogs.remove(command);
      _setSourceActive(source, command, false);
    });
  }

  @visibleForTesting
  void handleEvent(GamepadEvent event) {
    if (_disposed) {
      return;
    }
    if (event is GamepadConnectionEvent) {
      if (!event.connected) {
        _handleDisconnect(event.gamepadId);
      }
      return;
    }
    if (!_enabled || _suspended) {
      return;
    }

    if (event is GamepadButtonEvent) {
      _handleButton(event.gamepadId, event.button, event.pressed);
      return;
    }
    if (event is! GamepadAxisEvent) {
      return;
    }
    // 非法 gamepadId（负数/超大）直接丢弃，避免污染 _axes 映射。
    // keyboard 专用 -1 由 handleKeyboardNavigation 内部使用，不走此路径。
    if (event.gamepadId < 0 || event.gamepadId > 1 << 20) {
      return;
    }
    final values = _axes.putIfAbsent(
      event.gamepadId,
      () => <GamepadAxis, double>{},
    );
    if (!event.value.isFinite) return;
    values[event.axis] = event.value.clamp(-1.0, 1.0);
    switch (event.axis) {
      case GamepadAxis.leftStickX:
      case GamepadAxis.leftStickY:
        _updateStick(event.gamepadId, values, left: true);
      case GamepadAxis.rightStickX:
      case GamepadAxis.rightStickY:
        _updateStick(event.gamepadId, values, left: false);
    }
  }

  void _handleButton(int gamepadId, GamepadButton button, bool pressed) {
    if (_disposed) {
      return;
    }
    if (gamepadId < 0 || gamepadId > 1 << 20) {
      return;
    }
    final command = switch (button) {
      GamepadButton.a => GamepadCommand.activate,
      GamepadButton.b => GamepadCommand.back,
      GamepadButton.x => GamepadCommand.secondaryAction,
      GamepadButton.y => GamepadCommand.contextAction,
      GamepadButton.leftShoulder => GamepadCommand.previousSection,
      GamepadButton.rightShoulder => GamepadCommand.nextSection,
      GamepadButton.leftTrigger => GamepadCommand.previousSecondarySection,
      GamepadButton.rightTrigger => GamepadCommand.nextSecondarySection,
      GamepadButton.back => GamepadCommand.view,
      GamepadButton.start => GamepadCommand.menu,
      GamepadButton.leftStickButton => GamepadCommand.leftStickClick,
      GamepadButton.rightStickButton => GamepadCommand.rightStickClick,
      GamepadButton.dpadUp => GamepadCommand.navigateUp,
      GamepadButton.dpadDown => GamepadCommand.navigateDown,
      GamepadButton.dpadLeft => GamepadCommand.navigateLeft,
      GamepadButton.dpadRight => GamepadCommand.navigateRight,
      GamepadButton.guide => null,
    };
    if (command != null) {
      _setSourceActive(
        (gamepadId: gamepadId, control: button),
        command,
        pressed,
      );
    }
  }

  void _updateStick(
    int gamepadId,
    Map<GamepadAxis, double> values, {
    required bool left,
  }) {
    if (_disposed) {
      return;
    }
    final xAxis = left ? GamepadAxis.leftStickX : GamepadAxis.rightStickX;
    final yAxis = left ? GamepadAxis.leftStickY : GamepadAxis.rightStickY;
    final x = values[xAxis] ?? 0.0;
    final y = values[yAxis] ?? 0.0;
    if (!x.isFinite || !y.isFinite) {
      return;
    }
    final radius = math.sqrt(x * x + y * y);
    if (!radius.isFinite) {
      return;
    }
    // Left stick moves focus, right stick scrolls. Y is positive downwards.
    final commands = left
        ? const <GamepadCommand>[
            GamepadCommand.navigateLeft,
            GamepadCommand.navigateRight,
            GamepadCommand.navigateUp,
            GamepadCommand.navigateDown,
          ]
        : const <GamepadCommand>[
            GamepadCommand.scrollLeft,
            GamepadCommand.scrollRight,
            GamepadCommand.scrollUp,
            GamepadCommand.scrollDown,
          ];
    final source = (
      gamepadId: gamepadId,
      control: left ? _InputControl.leftStick : _InputControl.rightStick,
    );

    int? desired;
    if (radius >= _stickDeadZone) {
      // Only the dominant axis wins, so a diagonal push cannot fire two
      // directions at once.
      if (x.abs() >= y.abs()) {
        desired = x < 0 ? 0 : 1;
      } else {
        desired = y < 0 ? 2 : 3;
      }
    } else if (radius > _stickReleaseThreshold) {
      // Between the release and press thresholds, keep whatever this stick
      // already holds instead of releasing it.
      for (var i = 0; i < commands.length; i++) {
        if (_activeSources[commands[i]]?.contains(source) ?? false) {
          desired = i;
          break;
        }
      }
    }

    // Release the previous direction before emitting a new one. A listener
    // may reset or suspend input synchronously while handling that command.
    for (var i = 0; i < commands.length; i++) {
      if (desired != i) _setSourceActive(source, commands[i], false);
    }
    if (desired != null) _setSourceActive(source, commands[desired], true);
  }

  void _setSourceActive(
    _CommandSource source,
    GamepadCommand command,
    bool active,
  ) {
    if (_disposed) {
      return;
    }
    if (!active) {
      final sources = _activeSources[command];
      if (sources == null || !sources.remove(source) || sources.isNotEmpty) {
        return;
      }
      _repeatTimers.remove(command)?.cancel();
      _activeSources.remove(command);
      return;
    }
    final sources =
        _activeSources.putIfAbsent(command, () => <_CommandSource>{});
    final wasEmpty = sources.isEmpty;
    if (!sources.add(source) || !wasEmpty) return;

    final since = _lastPress[command];
    final duplicate = since != null && since.elapsed < _duplicateWindow;
    final generation = _generation;
    if (!duplicate) {
      (_lastPress[command] ??= Stopwatch()..start()).reset();
      _emit(command, source.gamepadId, isRepeat: false);
    }
    // Deduplication suppresses the extra edge, not a real sustained hold.
    if (generation == _generation &&
        identical(_activeSources[command], sources) &&
        _repeatableCommands.contains(command)) {
      _scheduleRepeat(command, sources, _initialRepeatDelay);
    }
  }

  void _scheduleRepeat(
      GamepadCommand command, Set<_CommandSource> sources, Duration delay) {
    try {
      _repeatTimers.remove(command)?.cancel();
    } catch (_) {}
    if (_disposed) {
      return;
    }
    // 重复节拍同样仅回落非法值，保留测试的 10ms/1h。
    final safeDelay = _sanitizeDuration(
      delay,
      fallback: _repeatInterval,
    );
    final generation = _generation;
    _repeatTimers[command] = Timer(safeDelay, () {
      _repeatTimers.remove(command);
      if (generation != _generation ||
          !identical(_activeSources[command], sources) ||
          sources.isEmpty) {
        return;
      }
      _emit(command, sources.first.gamepadId, isRepeat: true);
      // Actions can release, replace, or reset this hold during dispatch.
      if (generation == _generation &&
          identical(_activeSources[command], sources) &&
          sources.isNotEmpty) {
        _scheduleRepeat(command, sources, _repeatInterval);
      }
    });
  }

  void _emit(
    GamepadCommand command,
    int gamepadId, {
    required bool isRepeat,
  }) {
    if (_disposed || _commands.isClosed) {
      return;
    }
    final generation = _generation;
    try {
      usingGamepad.value = true;
    } catch (_) {
      return;
    }
    if (generation == _generation && !_commands.isClosed && !_disposed) {
      try {
        _commands.add(GamepadCommandEvent(
          command: command,
          gamepadId: gamepadId,
          isRepeat: isRepeat,
        ));
      } catch (_) {
        // 监听方在 dispatch 中同步 dispose 时忽略。
      }
    }
  }

  /// Ignore background events, including those from globally opened Linux pads.
  void setSuspended(bool suspended) {
    if (_suspended == suspended) return;
    _suspended = suspended;
    reset();
  }

  void reset() {
    _generation++;
    for (final timer in _repeatTimers.values) {
      try {
        timer.cancel();
      } catch (_) {}
    }
    _repeatTimers.clear();
    for (final timer in _keyboardNavigationWatchdogs.values) {
      try {
        timer.cancel();
      } catch (_) {}
    }
    _keyboardNavigationWatchdogs.clear();
    _activeSources.clear();
    _axes.clear();
    _lastPress.clear();
  }

  /// Releases everything a vanished controller held so a disconnect mid-hold
  /// cannot leave a command repeating forever.
  void _handleDisconnect(int gamepadId) {
    _axes.remove(gamepadId);
    for (final command in _activeSources.keys.toList()) {
      final sources = _activeSources[command]
              ?.where((source) => source.gamepadId == gamepadId)
              .toList() ??
          const <_CommandSource>[];
      for (final source in sources) {
        _setSourceActive(source, command, false);
      }
    }
  }

  bool _disposed = false;

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    reset();
    try {
      await _subscription?.cancel();
    } catch (_) {}
    _subscription = null;
    try {
      if (!_commands.isClosed) {
        await _commands.close();
      }
    } catch (_) {}
    try {
      usingGamepad.dispose();
    } catch (_) {}
  }
}
