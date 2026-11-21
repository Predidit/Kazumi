import 'dart:async';
import 'dart:collection';

class SyncplayPlaybackCoordinator {
  SyncplayPlaybackCoordinator({
    required this.playing,
    required this.position,
    required this.duration,
    required this.pause,
    required this.play,
    required this.seek,
    required this.onPositionSample,
    required this.onError,
    Duration Function()? now,
  }) : _now = now ?? (Stopwatch()..start()).elapsedDuration;

  final bool Function() playing;
  final double Function() position;
  final double Function() duration;
  final Future<void> Function() pause;
  final Future<void> Function() play;
  final Future<void> Function(double) seek;
  final void Function(double) onPositionSample;
  final void Function(Object, StackTrace) onError;
  final Duration Function() _now;
  final Queue<_PlaybackState> _controls = Queue();
  _PlaybackState? _latest;
  _PlaybackState? _settling;
  Duration? _settlingSince;
  Duration? _driftSince;
  int _driftDirection = 0;
  bool? _desiredPaused;
  bool _disposed = false;
  Future<void>? _running;

  Future<void> get idle => _running ?? Future.value();

  void update({
    required double position,
    required bool paused,
    bool doSeek = false,
    bool allowPlaybackChange = true,
  }) {
    if (_disposed) return;
    final stateChanged =
        allowPlaybackChange && paused != (_desiredPaused ?? !playing());
    final state = _PlaybackState(
      position,
      paused,
      doSeek,
      _now(),
      allowPlaybackChange,
      changePlayback: stateChanged,
    );
    if (allowPlaybackChange) _desiredPaused = paused;
    if (doSeek || stateChanged) {
      _controls.add(state);
    } else {
      _latest = state;
    }
    _start();
  }

  void _start() {
    _running ??= _drain().whenComplete(() {
      _running = null;
      if (!_disposed && (_controls.isNotEmpty || _latest != null)) _start();
    });
  }

  Future<void> _drain() async {
    await Future<void>.value();
    while (!_disposed && (_controls.isNotEmpty || _latest != null)) {
      final control = _controls.isNotEmpty;
      final state = control ? _controls.removeFirst() : _latest!;
      if (!control) _latest = null;
      try {
        if (control) {
          _resetDrift();
          if (state.changePlayback) {
            await (state.paused ? pause() : play());
            if (_disposed) return;
            onPositionSample(position());
          }
          if (state.doSeek && duration() > 0) {
            await seek(_target(state));
            if (_disposed) return;
            onPositionSample(position());
          }
          _settling = state;
          _settlingSince = _now();
          _latest = null;
          continue;
        }
        if (_settling case final settling?) {
          final observed =
              (!settling.allowPlaybackChange || playing() != settling.paused) &&
              (!settling.doSeek || (position() - _target(settling)).abs() <= 1);
          if (observed ||
              _now() - _settlingSince! >= const Duration(seconds: 5)) {
            _settling = null;
            _settlingSince = null;
            onPositionSample(position());
          }
          _resetDrift();
          continue;
        }
        final difference = _target(state) - position();
        if (difference.abs() <= 1 || duration() <= 0) {
          _resetDrift();
          continue;
        }
        final direction = difference.sign.toInt();
        if (_driftDirection != direction) {
          _driftDirection = direction;
          _driftSince = _now();
          continue;
        }
        if (_now() - _driftSince! < const Duration(seconds: 2)) continue;
        _resetDrift();
        await seek(_target(state));
        if (_disposed) return;
        onPositionSample(position());
        _settling = _PlaybackState(
          state.position,
          state.paused,
          true,
          state.receivedAt,
          false,
        );
        _settlingSince = _now();
        _latest = null;
      } catch (error, stackTrace) {
        if (_disposed) return;
        _controls.clear();
        _latest = null;
        _settling = null;
        _desiredPaused = null;
        _resetDrift();
        onError(error, stackTrace);
      }
    }
  }

  double _target(_PlaybackState state) =>
      state.position +
      (state.paused ? 0 : (_now() - state.receivedAt).inMicroseconds / 1000000);

  void _resetDrift() {
    _driftSince = null;
    _driftDirection = 0;
  }

  void dispose() {
    _disposed = true;
    _controls.clear();
    _latest = null;
  }
}

class _PlaybackState {
  const _PlaybackState(
    this.position,
    this.paused,
    this.doSeek,
    this.receivedAt,
    this.allowPlaybackChange, {
    this.changePlayback = false,
  });

  final double position;
  final bool paused;
  final bool doSeek;
  final Duration receivedAt;
  final bool allowPlaybackChange;
  final bool changePlayback;
}

extension on Stopwatch {
  Duration elapsedDuration() => elapsed;
}
