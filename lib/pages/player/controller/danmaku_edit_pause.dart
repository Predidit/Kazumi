/// What the player should do when the danmaku composer focus changes.
enum DanmakuEditPauseAction { none, pause, resume }

/// Pauses playback while the danmaku composer is focused, and resumes it once
/// the composer loses focus — but only when this controller is what paused it, so
/// a video the user paused manually stays paused and a disabled setting never
/// touches playback at all.
///
/// Resuming on every blur is only safe because the composer is edited behind a
/// barrier (see `PlayerItemPanel`): while it has focus, everything except the
/// composer row ignores pointer events and a transparent barrier swallows them.
/// A tap on the video or on the play/pause button therefore cannot resume *and*
/// toggle playback in the same gesture — that double toggle used to leave the
/// video paused no matter what the user tapped.
class DanmakuEditPauseController {
  bool _pausedByEdit = false;

  /// Whether playback is currently paused because of the danmaku composer.
  bool get pausedByEdit => _pausedByEdit;

  /// Resolves a focus change into the action the caller should run.
  DanmakuEditPauseAction onFocusChanged({
    required bool hasFocus,
    required bool enabled,
    required bool playing,
  }) {
    if (hasFocus) {
      if (!enabled || !playing || _pausedByEdit) {
        return DanmakuEditPauseAction.none;
      }
      _pausedByEdit = true;
      return DanmakuEditPauseAction.pause;
    }
    if (!_pausedByEdit) {
      return DanmakuEditPauseAction.none;
    }
    _pausedByEdit = false;
    return DanmakuEditPauseAction.resume;
  }
}
