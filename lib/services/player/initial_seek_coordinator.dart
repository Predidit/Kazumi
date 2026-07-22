import 'dart:async';

typedef InitialSeek = Future<void> Function(Duration position);

/// Applies a resume offset only after browser media metadata is available.
///
/// Native media backends already honor `Media.start`; callers keep [enabled]
/// false there. Web HLS needs this explicit seek because its hls.js path does
/// not translate `Media.start` into an HTMLMediaElement seek.
Future<bool> applyInitialSeekAfterOpen({
  required bool enabled,
  required Duration offset,
  required Duration currentDuration,
  required Stream<Duration> durationChanges,
  required InitialSeek seek,
  required bool Function() isCurrent,
  Duration readinessTimeout = const Duration(seconds: 15),
}) async {
  if (!enabled || offset <= Duration.zero || !isCurrent()) {
    return false;
  }

  if (currentDuration <= Duration.zero) {
    try {
      await durationChanges
          .firstWhere((duration) => duration > Duration.zero)
          .timeout(readinessTimeout);
    } catch (_) {
      return false;
    }
  }

  if (!isCurrent()) return false;
  await seek(offset);
  return isCurrent();
}
