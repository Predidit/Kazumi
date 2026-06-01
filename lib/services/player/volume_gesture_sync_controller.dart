import 'dart:async';

class VolumeGestureSyncController {
  VolumeGestureSyncController({
    required this.updateVolume,
    required this.setSettledVolume,
    required this.invalidatePreciseVolume,
    required this.syncVolumeToDevice,
  });

  final void Function(double value) updateVolume;
  final void Function(double value) setSettledVolume;
  final void Function() invalidatePreciseVolume;
  final Future<void> Function(double value) syncVolumeToDevice;

  int _generation = 0;
  bool _syncInFlight = false;
  double? _pendingVolume;
  double? _queuedVolume;
  double? _syncingVolume;
  Completer<void>? _idleCompleter;

  void updateDuringGesture(double value) {
    final volume = value.clamp(0.0, 100.0).toDouble();
    _pendingVolume = volume;
    updateVolume(volume);
    _queueVolume(volume);
  }

  Future<void> finishGesture() async {
    final generation = _generation;
    final volume = _pendingVolume;
    if (volume != null) {
      setSettledVolume(volume);
      _queueVolume(volume);
    }
    await _waitForDrain(generation);
    if (generation != _generation) {
      return;
    }
    _pendingVolume = null;
    invalidatePreciseVolume();
  }

  Future<void> cancel() async {
    _generation++;
    _pendingVolume = null;
    _queuedVolume = null;
    _completeIdleWaiter();
    await _waitForDrain(_generation);
  }

  void _queueVolume(double volume) {
    if (_syncInFlight && _syncingVolume == volume) {
      _queuedVolume = null;
      return;
    }
    _queuedVolume = volume;
    if (!_syncInFlight) {
      unawaited(_drainQueuedVolume(_generation));
    }
  }

  Future<void> _drainQueuedVolume(int generation) async {
    if (_syncInFlight) {
      return;
    }
    _syncInFlight = true;
    try {
      while (generation == _generation) {
        final volume = _queuedVolume;
        if (volume == null) {
          break;
        }
        _queuedVolume = null;
        _syncingVolume = volume;
        try {
          await syncVolumeToDevice(volume);
        } finally {
          if (_queuedVolume == volume) {
            _queuedVolume = null;
          }
          _syncingVolume = null;
        }
      }
    } finally {
      _syncInFlight = false;
      if (_queuedVolume != null) {
        unawaited(_drainQueuedVolume(_generation));
      } else {
        _completeIdleWaiter();
      }
    }
  }

  Future<void> _waitForDrain(int generation) async {
    while (
        generation == _generation && (_syncInFlight || _queuedVolume != null)) {
      final completer = _idleCompleter ??= Completer<void>();
      await completer.future;
    }
  }

  void _completeIdleWaiter() {
    final completer = _idleCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }
    completer.complete();
    _idleCompleter = null;
  }
}
