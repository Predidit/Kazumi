import 'package:kazumi/pages/player/controller/player_danmaku_controller.dart';
import 'package:kazumi/pages/player/controller/player_playback_controller.dart';
import 'package:media_kit/media_kit.dart';

class _InteractiveSeekSession {
  _InteractiveSeekSession({
    required this.pauseCompleted,
    required this.initialPosition,
    required this.wasPlaying,
    required this.player,
  }) : target = initialPosition;

  final Future<void> pauseCompleted;
  final Duration initialPosition;
  final bool wasPlaying;
  final Player? player;
  Duration target;
  Future<bool>? completion;
}

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
  _InteractiveSeekSession? _interactiveSession;

  bool get hasActiveInteractiveSeek => _interactiveSession != null;

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
    final initialPosition = _playback.currentPosition;
    final previousSession = _interactiveSession;
    // Keep the original playing state across overlapping gestures.
    final wasPlaying = previousSession != null && _isCurrent(previousSession)
        ? previousSession.wasPlaying
        : _playback.playerPlaying;
    final player = _playback.mediaPlayer;
    _interactiveSession = _InteractiveSeekSession(
      pauseCompleted: _pause(enableSync: false),
      initialPosition: initialPosition,
      wasPlaying: wasPlaying,
      player: player,
    );
  }

  bool updateInteractiveSeek(Duration target) {
    final session = _interactiveSession;
    if (session == null || !_isCurrent(session) || session.completion != null) {
      return false;
    }
    session.target = _normalize(target);
    _playback.currentPosition = session.target;
    return true;
  }

  Future<bool> finishInteractiveSeek({bool cancelled = false}) {
    final session = _interactiveSession;
    if (session == null) {
      return Future<bool>.value(false);
    }
    return session.completion ??=
        _finishInteractiveSeek(session, cancelled: cancelled);
  }

  void invalidateInteractiveSeek() {
    _interactiveSession = null;
  }

  Future<bool> _finishInteractiveSeek(
    _InteractiveSeekSession session, {
    required bool cancelled,
  }) async {
    try {
      if (!_isCurrent(session)) {
        return false;
      }
      if (cancelled) {
        // Only the preview moved; cancellation needs no native seek.
        _playback.currentPosition = session.initialPosition;
      }
      await session.pauseCompleted;
      if (!_isCurrent(session)) {
        return false;
      }
      if (!cancelled) {
        await seekTo(session.target);
        if (!_isCurrent(session)) {
          return false;
        }
      }
      if (!cancelled || session.wasPlaying) {
        await _play(enableSync: false);
      }
      return _isCurrent(session);
    } finally {
      if (identical(_interactiveSession, session)) {
        _interactiveSession = null;
      }
    }
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

  bool _isCurrent(_InteractiveSeekSession session) =>
      identical(_interactiveSession, session) &&
      identical(_playback.mediaPlayer, session.player);

  Future<void> _settle(Future<void> operation) async {
    try {
      await operation;
    } catch (_) {
      // The caller receives the error; the queue only needs to remain usable.
    }
  }
}
