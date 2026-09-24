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
    Duration operationTimeout = const Duration(seconds: 3),
  })  : _readPosition = readPosition,
        _isPlaying = isPlaying,
        _writePreview = writePreview,
        _normalize = normalize,
        _pause = pause,
        _seek = seek,
        _play = play,
        // 非正或超大超时会导致立刻 Timeout 或永不超时：回落到 3s。
        // 保留小到 1ms 的合法测试超时，不做下限钳制。
        operationTimeout = (operationTimeout <= Duration.zero ||
                operationTimeout > const Duration(days: 1))
            ? const Duration(seconds: 3)
            : operationTimeout;

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
    // 读取/归一化失败时不建会话：调用方（拖拽手势）无需 try/catch 也不崩溃。
    late Duration initialPosition;
    late final bool wasPlaying;
    try {
      initialPosition = _normalize(_readPosition());
      wasPlaying = _isPlaying();
    } catch (_) {
      return;
    }
    // 负时长/超大时长防御：归一化器应钳制，但此处再钳一次避免污染预览。
    if (initialPosition < Duration.zero) {
      try {
        initialPosition = _normalize(Duration.zero);
      } catch (_) {
        return;
      }
    }
    late final Future<void> pauseCompleted;
    try {
      pauseCompleted =
          wasPlaying ? Future<void>.sync(_pause) : Future<void>.value();
    } catch (_) {
      return;
    }
    _session = _InteractiveSeekSession(
      initialPosition: initialPosition,
      wasPlaying: wasPlaying,
      pauseCompleted: pauseCompleted,
    );
    // pause() 同步抛错会被 Future.sync 转为 error future，commit 时按失败抛出；
    // 此处不吞错，仅保证半初始化会话不残留（pauseCompleted 已捕获则会话有效）。
  }

  bool update(Duration target) {
    final session = _session;
    if (session == null || session.completion != null) {
      return false;
    }
    try {
      session.target = _normalize(target);
    } catch (_) {
      return false;
    }
    try {
      _writePreview(session.target);
    } catch (_) {
      return false;
    }
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
      // 预览恢复失败不应阻塞播放恢复：best-effort。
      try {
        _writePreview(session.initialPosition);
      } catch (_) {}
      await session.pauseCompleted.timeout(operationTimeout);
      if (!_isCurrent(session)) {
        return false;
      }

      try {
        _writePreview(session.initialPosition);
      } catch (_) {}
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
