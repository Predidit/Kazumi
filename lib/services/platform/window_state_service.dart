import 'dart:async';

import 'package:flutter/services.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/device.dart';
import 'package:window_manager/window_manager.dart';

const _windowsIntMin = -2147483648;
const _windowsIntMax = 2147483647;

int? _parseWindowsInt(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < _windowsIntMin ||
      value > _windowsIntMax) {
    return null;
  }
  return value.toInt();
}

/// Physical screen coordinates and outer bounds, independent of plugin logical coordinates.
class WindowBounds {
  const WindowBounds._(this.x, this.y, this.width, this.height);

  final int x;
  final int y;
  final int width;
  final int height;

  static WindowBounds? tryParse(Object? value) {
    // Hive and platform maps may have different generic types, validate before casting.
    if (value is! Map) return null;
    final x = _parseWindowsInt(value['x']);
    final y = _parseWindowsInt(value['y']);
    final width = _parseWindowsInt(value['width']);
    final height = _parseWindowsInt(value['height']);
    if (x == null || y == null || width == null || height == null) {
      return null;
    }
    // Negative coordinates are valid; right and bottom must fit a Windows RECT.
    if (width <= 0 ||
        height <= 0 ||
        x + width > _windowsIntMax ||
        y + height > _windowsIntMax) {
      return null;
    }
    return WindowBounds._(x, y, width, height);
  }

  Map<String, int> toMap() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

/// Immutable values for storage and PiP snapshots, serialization creates a new map.
class WindowsWindowState {
  const WindowsWindowState({
    required this.normalBounds,
    required this.wasMaximized,
  });

  final WindowBounds normalBounds;
  final bool wasMaximized;

  static WindowsWindowState? tryParse(Object? value) {
    if (value is! Map) return null;
    final bounds = WindowBounds.tryParse(value['normalBounds']);
    final maximized = value['wasMaximized'];
    if (bounds == null || maximized is! bool) return null;
    return WindowsWindowState(normalBounds: bounds, wasMaximized: maximized);
  }

  Map<String, Object> toMap() => {
    'normalBounds': normalBounds.toMap(),
    'wasMaximized': wasMaximized,
  };
}

class WindowGeometry {
  const WindowGeometry._({
    required this.isVisible,
    required this.isMinimized,
    required this.isMaximized,
    required this.normalBounds,
  });

  final bool isVisible;
  final bool isMinimized;
  final bool isMaximized;
  final WindowBounds? normalBounds;

  static WindowGeometry? tryParse(Object? value) {
    if (value is! Map) return null;
    final visible = value['isVisible'];
    final minimized = value['isMinimized'];
    final maximized = value['isMaximized'];
    if (visible is! bool || minimized is! bool || maximized is! bool) {
      return null;
    }
    // Never use minimized or maximized bounds as normal bounds.
    // Hidden normal windows can still be read during startup.
    final bounds = minimized || maximized
        ? null
        : WindowBounds.tryParse(value['normalBounds']);
    if (!minimized && !maximized && bounds == null) return null;
    return WindowGeometry._(
      isVisible: visible,
      isMinimized: minimized,
      isMaximized: maximized,
      normalBounds: bounds,
    );
  }
}

/// Shared Windows geometry service for startup, PiP, and exit handling.
class WindowStateService with WindowListener {
  WindowStateService._();

  static final instance = WindowStateService._();
  static const _channel = MethodChannel('com.predidit.kazumi/intent');

  WindowsWindowState? _cachedWindowState;
  // Keep the write baseline separate: startup may correct cached bounds before
  // listening starts, and the first observation must still persist that change.
  WindowsWindowState? _lastQueuedState;
  WindowsWindowState? _pipSnapshot;
  // PiP must stay paused even when its entry snapshot is unavailable.
  // Fullscreen is checked per observation; a missing leave event must not latch
  // sampling off, and a late fullscreen event must not release PiP protection.
  bool _pipSamplingPaused = false;
  Timer? _debounce;
  int _revision = 0;
  bool _listening = false;
  bool _exiting = false;
  Future<void> _saveTail = Future<void>.value();

  /// Load only after storage initialization succeeds, before showing the window.
  WindowsWindowState? loadSavedState() {
    final raw = GStorage.getSetting(SettingsKeys.windowsWindowState);
    final state = WindowsWindowState.tryParse(raw);
    _cachedWindowState = state;
    _lastQueuedState = state;
    return state;
  }

  Future<void> _prepareNormalWindow() async {
    if (await windowManager.isMinimized()) await windowManager.restore();
    if (await windowManager.isMaximized()) await windowManager.unmaximize();
  }

  /// Return whether the specified normal bounds were successfully applied.
  Future<bool> restoreNormalLayout(
    WindowsWindowState state, [
    Size? defaultSize,
  ]) async {
    try {
      await _prepareNormalWindow();
      final bounds = await restoreWindowBounds(state.normalBounds);
      _cachedWindowState = WindowsWindowState(
        normalBounds: bounds,
        wasMaximized: state.wasMaximized,
      );
      return true;
    } catch (_) {
      // Only normal-bounds failures select the default layout.
      // Maximization is a separate operation so its failure cannot discard restored bounds.
      await _restoreDefaultLayout(
        defaultSize ?? await defaultDesktopWindowSize(),
      );
      return false;
    }
  }

  Future<void> _restoreDefaultLayout(Size defaultSize) async {
    // Do not retain old bounds if the default layout's readback fails.
    _cachedWindowState = null;
    await _prepareNormalWindow();
    await windowManager.setSize(defaultSize);
    await windowManager.center();
    await cacheDefaultLayout();
  }

  /// Hidden normal windows are readable here; daily sampling requires visibility.
  Future<void> cacheDefaultLayout() async {
    try {
      final geometry = await captureWindowGeometry();
      if (!geometry.isMinimized && !geometry.isMaximized) {
        _cachedWindowState = WindowsWindowState(
          normalBounds: geometry.normalBounds!,
          wasMaximized: false,
        );
      }
    } catch (_) {
      // A failed read must not trigger another layout change; events can retry.
    }
  }

  Future<void> maximizeRestoredLayout() async {
    try {
      await windowManager.maximize();
    } catch (_) {
      // Keep the restored rectangle and let sampling determine the actual flag.
    }
  }

  /// Read the entry layout before any PiP operation can unmaximize or resize it.
  Future<void> beginPip() async {
    if (_pipSnapshot == null) {
      try {
        final geometry = await captureWindowGeometry();
        if (geometry.isVisible && !geometry.isMinimized) {
          final bounds = geometry.isMaximized
              ? _cachedWindowState?.normalBounds
              : geometry.normalBounds;
          // Maximized geometry supplies only the flag, never normal bounds.
          if (bounds != null) {
            final snapshot = WindowsWindowState(
              normalBounds: bounds,
              wasMaximized: geometry.isMaximized,
            );
            _pipSnapshot = snapshot;
            _cachedWindowState = snapshot;
          }
        }
      } catch (_) {
        // PiP can still enter; exit will select the default layout.
      }
    }
    // Invalidate pending reads synchronously before the caller changes layout.
    // Already queued normal-layout writes can finish independently.
    _pipSamplingPaused = true;
    _debounce?.cancel();
    ++_revision;
  }

  /// Called after PiP has released always-on-top and its aspect-ratio lock.
  Future<void> restoreAfterPip() async {
    final snapshot = _pipSnapshot;
    if (snapshot == null) {
      await _restoreDefaultLayout(await defaultDesktopWindowSize());
    } else {
      // Resolve the current default size only if normal restoration fails.
      final restored = await restoreNormalLayout(snapshot);
      if (restored && snapshot.wasMaximized) {
        await maximizeRestoredLayout();
      }
    }
    // Resume only after a restored or default layout completes.
    // A failed cleanup must not unconditionally expose partially applied PiP bounds to storage.
    _pipSnapshot = null;
    _pipSamplingPaused = false;
    _scheduleCapture();
  }

  /// Owned solely by main's display callback, after restoration, show and focus.
  /// A successful start is permanent; repeated calls must not replace handlers.
  void startListening() {
    if (_listening) {
      return;
    }
    // This service owns the intent channel's Dart receiver. Other users of the
    // channel only send requests; registering again would replace this handler.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'windowGeometryChanged') {
        // Native and plugin events share debounce; read actual geometry later.
        _scheduleCapture();
        return;
      }
      throw MissingPluginException(
        'Unknown intent notification: ${call.method}',
      );
    });
    windowManager.addListener(this);
    _listening = true;
    _scheduleCapture();
  }

  void _scheduleCapture() {
    final revision = ++_revision;
    _debounce?.cancel();
    if (!_listening || _pipSamplingPaused || _exiting) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_captureAndSave(revision));
    });
  }

  bool _isCurrent(int revision) =>
      _listening && !_pipSamplingPaused && !_exiting && revision == _revision;

  Future<void> _captureAndSave(int revision) async {
    try {
      if (!_isCurrent(revision)) {
        return;
      }
      // Query the plugin's state for each observation rather than persisting a
      // fullscreen pause that would require a leave event to resume sampling.
      final fullScreen = await windowManager.isFullScreen();
      if (!_isCurrent(revision) || fullScreen) {
        return;
      }
      final geometry = await captureWindowGeometry();
      // Events invalidate in-flight queries. Geometry reads never wait for disk
      // writes, and a late result must not replace a more recent observation.
      if (!_isCurrent(revision) ||
          !geometry.isVisible ||
          geometry.isMinimized) {
        return;
      }
      final bounds = geometry.isMaximized
          ? _cachedWindowState?.normalBounds
          : geometry.normalBounds;
      // A maximized outer rectangle is never a substitute for normal bounds.
      if (bounds == null) {
        return;
      }
      final state = WindowsWindowState(
        normalBounds: bounds,
        wasMaximized: geometry.isMaximized,
      );
      _cachedWindowState = state;
      if (_sameState(state, _lastQueuedState)) {
        return;
      }
      _lastQueuedState = state;
      _enqueueSave(state);
    } catch (_) {
      // A sampling failure skips this observation without changing the layout.
    }
  }

  bool _sameState(WindowsWindowState a, WindowsWindowState? b) =>
      b != null &&
      a.wasMaximized == b.wasMaximized &&
      a.normalBounds.x == b.normalBounds.x &&
      a.normalBounds.y == b.normalBounds.y &&
      a.normalBounds.width == b.normalBounds.width &&
      a.normalBounds.height == b.normalBounds.height;

  void _enqueueSave(WindowsWindowState state) {
    // Capture the immutable record now; only storage operations are serialized.
    _saveTail = _saveTail.then((_) async {
      try {
        await GStorage.putSetting(
          SettingsKeys.windowsWindowState,
          state.toMap(),
        );
      } catch (_) {
        // Allow later writes to proceed; this does not mean this write succeeded.
      }
    });
  }

  /// Stop sampling synchronously and wait for the final cached layout write.
  Future<void> saveBeforeExit() {
    if (_exiting) {
      return _saveTail;
    }
    _exiting = true;
    _debounce?.cancel();
    ++_revision;
    // Never query exit-time geometry: fullscreen, PiP, or hidden windows may
    // expose temporary bounds. The immutable cache is the final write snapshot.
    // In-flight reads become stale; await writes including the final snapshot.
    final state = _cachedWindowState;
    if (state != null) {
      // Submit even if unchanged, including after a failed daily write.
      _enqueueSave(state);
    }
    return _saveTail;
  }

  @override
  void onWindowEnterFullScreen() {
    // Invalidate pending reads synchronously; the next debounced observation
    // checks fullscreen before reading geometry. PiP and exit gates still apply.
    _scheduleCapture();
  }

  @override
  void onWindowLeaveFullScreen() {
    // A leave event requests a fresh observation without releasing PiP's pause.
    // If it is missing, later geometry events can still schedule observations.
    _scheduleCapture();
  }

  @override
  void onWindowMove() => _scheduleCapture();

  @override
  void onWindowResize() => _scheduleCapture();

  @override
  void onWindowMaximize() => _scheduleCapture();

  @override
  void onWindowUnmaximize() => _scheduleCapture();

  @override
  void onWindowMinimize() => _scheduleCapture();

  @override
  void onWindowRestore() => _scheduleCapture();

  Future<WindowGeometry> captureWindowGeometry() async {
    final value = await _channel.invokeMethod<Object?>('captureWindowGeometry');
    final geometry = WindowGeometry.tryParse(value);
    if (geometry == null) {
      throw PlatformException(code: 'InvalidWindowGeometry');
    }
    return geometry;
  }

  Future<WindowBounds> restoreWindowBounds(WindowBounds bounds) async {
    final value = await _channel.invokeMethod<Object?>(
      'restoreWindowBounds',
      bounds.toMap(),
    );
    final applied = WindowBounds.tryParse(value);
    if (applied == null) {
      throw PlatformException(code: 'InvalidWindowBounds');
    }
    return applied;
  }
}
