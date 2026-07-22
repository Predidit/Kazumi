import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/services/player/playback_configurator_contract.dart';
import 'package:media_kit/media_kit.dart';

PlaybackConfigurator createPlaybackConfigurator({
  required String Function() shaderDirectoryPath,
}) {
  return const WebPlaybackConfigurator();
}

/// Web uses media_kit's HTMLVideoElement implementation without native mpv
/// properties. The media URL is same-origin, so upstream headers remain in the
/// server-side playback session and are intentionally never exposed here.
class WebPlaybackConfigurator implements PlaybackConfigurator {
  const WebPlaybackConfigurator();

  @override
  Map<String, String> mediaHttpHeaders(
    Map<String, String> requestedHeaders,
  ) =>
      const <String, String>{};

  @override
  bool resolveAutoPlay(bool configuredAutoPlay) => false;

  @override
  bool get usePlayerVolume => true;

  @override
  bool requiresExplicitInitialSeek(String mediaUrl) {
    return mediaUrl.toLowerCase().contains('m3u8');
  }

  @override
  Future<PlaybackPlatformConfiguration?> configurePlayer(
    Player player,
    PlaybackPlatformOptions options, {
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) return null;
    return PlaybackPlatformConfiguration(
      videoRenderer: null,
      hardwareAccelerationEnabled: false,
      hardwareDecoder: 'no',
      superResolutionMode: SuperResolutionMode.off,
    );
  }

  @override
  Future<SuperResolutionMode?> applySuperResolution(
    Player player,
    SuperResolutionMode mode, {
    required bool Function() isCurrent,
  }) async {
    return isCurrent() ? SuperResolutionMode.off : null;
  }
}
