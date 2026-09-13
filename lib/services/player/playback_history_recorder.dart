import 'package:kazumi/utils/async_serial_queue.dart';

typedef PlaybackProgressWriter = Future<void> Function(
    Duration position, Duration duration);

/// One recorder per native media session. Inputs must come from native state,
/// never from a requested seek target or a prepared route.
class PlaybackHistoryRecorder {
  PlaybackHistoryRecorder(this._write);

  final PlaybackProgressWriter _write;
  final AsyncSerialQueue _writes = AsyncSerialQueue();
  bool _hasPlayed = false;
  (Duration, Duration)? _saved;

  void observePlaying(bool playing) {
    _hasPlayed |= playing;
  }

  Future<void> record({
    required Duration position,
    required Duration duration,
    required bool playing,
  }) {
    observePlaying(playing);
    if (!_hasPlayed ||
        duration <= Duration.zero ||
        position < Duration.zero ||
        position > duration) {
      return Future<void>.value();
    }
    final snapshot = (position, duration);
    return _writes.run(() async {
      if (_saved == snapshot) return;
      await _write(position, duration);
      _saved = snapshot;
    });
  }
}
