import 'dart:async';

typedef HistoryAutoSyncEnabled = bool Function();
typedef HistoryAutoSyncOperation = Future<void> Function();
typedef HistoryAutoSyncErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
);

/// Coalesces frequent playback-history writes into bounded WebDAV syncs.
///
/// A quiet period triggers a trailing sync, while [maxWait] guarantees that
/// continuous playback still uploads periodically. [flush] drains both an
/// in-flight sync and any changes that arrived while it was running.
class HistoryAutoSyncScheduler {
  HistoryAutoSyncScheduler({
    required HistoryAutoSyncEnabled isEnabled,
    required HistoryAutoSyncOperation sync,
    HistoryAutoSyncErrorHandler? onError,
    this.debounce = const Duration(seconds: 15),
    this.maxWait = const Duration(minutes: 2),
  })  : assert(debounce > Duration.zero),
        assert(maxWait > Duration.zero),
        _isEnabled = isEnabled,
        _sync = sync,
        _onError = onError;

  final HistoryAutoSyncEnabled _isEnabled;
  final HistoryAutoSyncOperation _sync;
  final HistoryAutoSyncErrorHandler? _onError;
  final Duration debounce;
  final Duration maxWait;

  Timer? _debounceTimer;
  Timer? _maxWaitTimer;
  Future<void>? _activeSync;
  bool _dirty = false;
  bool _disposed = false;

  bool get hasPendingWork => _dirty || _activeSync != null;

  void markDirty() {
    if (_disposed) {
      return;
    }
    if (!_enabledSafely()) {
      _dirty = false;
      _cancelTimers();
      return;
    }

    _dirty = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, _onDebounceElapsed);
    _maxWaitTimer ??= Timer(maxWait, _onMaxWaitElapsed);
  }

  Future<void> flush() async {
    if (_disposed) {
      return;
    }
    _cancelTimers();

    while (true) {
      final activeSync = _activeSync;
      if (activeSync != null) {
        await activeSync;
        continue;
      }
      if (!_dirty) {
        return;
      }
      if (!_enabledSafely()) {
        _dirty = false;
        return;
      }
      await _syncDirtyState();
    }
  }

  void dispose() {
    _disposed = true;
    _dirty = false;
    _cancelTimers();
  }

  void _onDebounceElapsed() {
    _debounceTimer = null;
    _runScheduledSync();
  }

  void _onMaxWaitElapsed() {
    _maxWaitTimer = null;
    _runScheduledSync();
  }

  void _runScheduledSync() {
    unawaited(
      _syncDirtyState().catchError((Object error, StackTrace stackTrace) {
        _onError?.call(error, stackTrace);
      }),
    );
  }

  Future<void> _syncDirtyState() {
    final activeSync = _activeSync;
    if (activeSync != null) {
      return activeSync;
    }
    if (!_dirty) {
      return Future<void>.value();
    }
    if (!_enabledSafely()) {
      _dirty = false;
      _cancelTimers();
      return Future<void>.value();
    }

    _dirty = false;
    _cancelTimers();
    final completer = Completer<void>();
    _activeSync = completer.future;
    unawaited(_performSync(completer));
    return completer.future;
  }

  Future<void> _performSync(Completer<void> completer) async {
    try {
      await _sync();
      completer.complete();
    } catch (error, stackTrace) {
      _dirty = true;
      completer.completeError(error, stackTrace);
    } finally {
      _activeSync = null;
      if (_dirty && !_disposed && _enabledSafely()) {
        _ensureRetryTimers();
      }
    }
  }

  void _ensureRetryTimers() {
    _debounceTimer ??= Timer(debounce, _onDebounceElapsed);
    _maxWaitTimer ??= Timer(maxWait, _onMaxWaitElapsed);
  }

  bool _enabledSafely() {
    try {
      return _isEnabled();
    } catch (_) {
      return false;
    }
  }

  void _cancelTimers() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _maxWaitTimer?.cancel();
    _maxWaitTimer = null;
  }
}
