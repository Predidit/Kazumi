import 'package:kazumi/pages/player/controller/interactive_seek_lifecycle.dart';
import 'package:kazumi/pages/player/controller/player_danmaku_controller.dart';
import 'package:kazumi/pages/player/controller/player_playback_controller.dart';

class PlayerSeekController {
  PlayerSeekController({
    required PlayerPlaybackController playback,
    required PlayerDanmakuController danmaku,
    required Future<void> Function({bool enableSync}) pause,
    required Future<void> Function({bool enableSync}) play,
    required Future<void> Function(bool enableSync) onSeekCompleted,
  })  : _playback = playback,
        _danmaku = danmaku,
        _pause = pause,
        _play = play,
        _onSeekCompleted = onSeekCompleted;

  final PlayerPlaybackController _playback;
  final PlayerDanmakuController _danmaku;
  final Future<void> Function({bool enableSync}) _pause;
  final Future<void> Function({bool enableSync}) _play;
  final Future<void> Function(bool enableSync) _onSeekCompleted;

  Future<void> _seekTail = Future<void>.value();
  late final InteractiveSeekLifecycle _interactiveSeek =
      InteractiveSeekLifecycle(
    readPosition: () => _playback.currentPosition,
    isPlaying: () => _playback.playing,
    writePreview: (position) => _playback.currentPosition = position,
    normalize: _normalize,
    pause: () => _pause(enableSync: false),
    seek: seekTo,
    play: () => _play(enableSync: false),
  );

  bool get hasActiveInteractiveSeek => _interactiveSeek.hasActiveSession;

  Future<void> seekTo(
    Duration target, {
    bool enableSync = true,
  }) {
    final player = _playback.mediaPlayer;
    if (player == null) {
      return Future<void>.value();
    }

    final normalizedTarget = _normalize(target);
    _playback.currentPosition = normalizedTarget;
    _danmaku.clearAndInvalidateScheduledDanmakus();

    final operation = _seekTail.then((_) async {
      if (!_playback.isCurrentPlayer(player)) {
        return;
      }
      try {
        await player.seek(normalizedTarget);
      } catch (_) {
        return;
      }
      if (_playback.isCurrentPlayer(player)) {
        await _onSeekCompleted(enableSync);
      }
    });
    _seekTail = _settle(operation);
    return operation;
  }

  Future<void> seekBy(
    Duration offset, {
    bool enableSync = true,
  }) =>
      seekTo(
        _playback.currentPosition + offset,
        enableSync: enableSync,
      );

  void beginInteractiveSeek() {
    _interactiveSeek.begin();
  }

  bool updateInteractiveSeek(Duration target) {
    return _interactiveSeek.update(target);
  }

  Future<bool> commitInteractiveSeek() {
    return _interactiveSeek.commit();
  }

  Future<bool> cancelInteractiveSeek() {
    return _interactiveSeek.cancel();
  }

  void invalidateInteractiveSeek() {
    _interactiveSeek.invalidate();
  }

  Duration _normalize(Duration target) {
    var milliseconds = target.inMilliseconds;
    if (milliseconds < 0) {
      milliseconds = 0;
    }
    final duration = _playback.duration;
    if (duration > Duration.zero && milliseconds > duration.inMilliseconds) {
      milliseconds = duration.inMilliseconds;
    }
    return Duration(milliseconds: milliseconds);
  }

  Future<void> _settle(Future<void> operation) async {
    try {
      await operation;
    } catch (_) {
      // The caller receives the error; the queue only needs to remain usable.
    }
  }
}
