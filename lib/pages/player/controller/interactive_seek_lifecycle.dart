typedef InteractiveSeekPositionReader = Duration Function();
typedef InteractiveSeekPlayingReader = bool Function();
typedef InteractiveSeekPreviewWriter = void Function(Duration position);
typedef InteractiveSeekAction = Future<void> Function();
typedef InteractiveSeekTargetAction = Future<void> Function(Duration target);
typedef InteractiveSeekNormalizer = Duration Function(Duration target);

class _InteractiveSeekSession {
  _InteractiveSeekSession({
    required this.initialPosition,
    required this.wasPlaying,
    required this.pauseCompleted,
  }) : target = initialPosition;

  final Duration initialPosition;
  final bool wasPlaying;
  final Future<void> pauseCompleted;
  Duration target;
  Future<bool>? completion;
}

/// Owns the pause/preview/commit lifecycle of one interactive seek gesture.
///
/// Preview updates only change the displayed position. The media player is
/// sought once, when the gesture commits. Cancelling restores the original
/// preview position and the playback state captured at gesture start.
class InteractiveSeekLifecycle {
  InteractiveSeekLifecycle({
    required InteractiveSeekPositionReader readPosition,
    required InteractiveSeekPlayingReader isPlaying,
    required InteractiveSeekPreviewWriter writePreview,
    required InteractiveSeekNormalizer normalize,
    required InteractiveSeekAction pause,
    required InteractiveSeekTargetAction seek,
    required InteractiveSeekAction play,
    this.operationTimeout = const Duration(seconds: 3),
  })  : _readPosition = readPosition,
        _isPlaying = isPlaying,
        _writePreview = writePreview,
        _normalize = normalize,
        _pause = pause,
        _seek = seek,
        _play = play;

  final InteractiveSeekPositionReader _readPosition;
  final InteractiveSeekPlayingReader _isPlaying;
  final InteractiveSeekPreviewWriter _writePreview;
  final InteractiveSeekNormalizer _normalize;
  final InteractiveSeekAction _pause;
  final InteractiveSeekTargetAction _seek;
  final InteractiveSeekAction _play;
  final Duration operationTimeout;

  _InteractiveSeekSession? _session;

  bool get hasActiveSession => _session != null;

  void begin() {
    if (_session != null) {
      return;
    }
    final initialPosition = _normalize(_readPosition());
    final wasPlaying = _isPlaying();
    _session = _InteractiveSeekSession(
      initialPosition: initialPosition,
      wasPlaying: wasPlaying,
      pauseCompleted:
          wasPlaying ? Future<void>.sync(_pause) : Future<void>.value(),
    );
  }

  bool update(Duration target) {
    final session = _session;
    if (session == null || session.completion != null) {
      return false;
    }
    session.target = _normalize(target);
    _writePreview(session.target);
    return true;
  }

  Future<bool> commit() {
    final session = _session;
    if (session == null) {
      return Future<bool>.value(false);
    }
    return session.completion ??= _commit(session);
  }

  Future<bool> cancel() {
    final session = _session;
    if (session == null) {
      return Future<bool>.value(false);
    }
    return session.completion ??= _cancel(session);
  }

  void invalidate() {
    _session = null;
  }

  Future<bool> _commit(_InteractiveSeekSession session) async {
    try {
      await session.pauseCompleted.timeout(operationTimeout);
      if (!_isCurrent(session)) {
        return false;
      }

      await _seek(session.target).timeout(operationTimeout);
      if (!_isCurrent(session)) {
        return false;
      }

      if (session.wasPlaying) {
        await _play().timeout(operationTimeout);
      }
      return _isCurrent(session);
    } finally {
      if (_isCurrent(session)) {
        _session = null;
      }
    }
  }

  Future<bool> _cancel(_InteractiveSeekSession session) async {
    try {
      _writePreview(session.initialPosition);
      await session.pauseCompleted.timeout(operationTimeout);
      if (!_isCurrent(session)) {
        return false;
      }

      _writePreview(session.initialPosition);
      if (session.wasPlaying) {
        await _play().timeout(operationTimeout);
      }
      return _isCurrent(session);
    } finally {
      if (_isCurrent(session)) {
        _session = null;
      }
    }
  }

  bool _isCurrent(_InteractiveSeekSession session) =>
      identical(_session, session);
}
