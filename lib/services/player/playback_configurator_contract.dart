import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:media_kit/media_kit.dart';

/// Platform-neutral inputs used while preparing a media_kit player.
class PlaybackPlatformOptions {
  const PlaybackPlatformOptions({
    required this.hardwareAccelerationEnabled,
    required this.hardwareDecoder,
    required this.androidEnableOpenSLES,
    required this.superResolutionMode,
  });

  final bool hardwareAccelerationEnabled;
  final String hardwareDecoder;
  final bool androidEnableOpenSLES;
  final SuperResolutionMode superResolutionMode;
}

/// Effective video-controller settings after platform-specific preparation.
class PlaybackPlatformConfiguration {
  const PlaybackPlatformConfiguration({
    required this.videoRenderer,
    required this.hardwareAccelerationEnabled,
    required this.hardwareDecoder,
    required this.superResolutionMode,
  });

  final String? videoRenderer;
  final bool hardwareAccelerationEnabled;
  final String hardwareDecoder;
  final SuperResolutionMode superResolutionMode;
}

/// Isolates native mpv configuration from the shared playback controller.
abstract interface class PlaybackConfigurator {
  /// Browsers must use the same-origin media gateway and cannot set protected
  /// request headers on HTMLMediaElement requests.
  Map<String, String> mediaHttpHeaders(Map<String, String> requestedHeaders);

  /// Native keeps the user's autoplay setting. Web deliberately waits for a
  /// user gesture before starting playback.
  bool resolveAutoPlay(bool configuredAutoPlay);

  /// Desktop and web players own their volume. Native mobile uses the system
  /// volume controller instead.
  bool get usePlayerVolume;

  /// Whether this backend needs a second seek after media metadata is ready.
  ///
  /// media_kit's Web HLS path does not apply [Media.start], while native mpv
  /// already does. Keeping this platform decision here avoids double-seeking
  /// native playback.
  bool requiresExplicitInitialSeek(String mediaUrl);

  /// Applies platform-specific player properties before VideoController is
  /// attached. A null result means ownership changed while awaiting setup.
  Future<PlaybackPlatformConfiguration?> configurePlayer(
    Player player,
    PlaybackPlatformOptions options, {
    required bool Function() isCurrent,
  });

  /// Applies a platform-specific super-resolution mode. A null result means
  /// ownership changed while awaiting setup; the returned value is the actual
  /// mode supported by the platform.
  Future<SuperResolutionMode?> applySuperResolution(
    Player player,
    SuperResolutionMode mode, {
    required bool Function() isCurrent,
  });
}
