import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/services/player/playback_configurator_contract.dart';
import 'package:media_kit/media_kit.dart';

PlaybackConfigurator createPlaybackConfigurator({
  required String Function() shaderDirectoryPath,
}) {
  return UnsupportedPlaybackConfigurator();
}

/// Conservative fallback for platforms without a dedicated implementation.
class UnsupportedPlaybackConfigurator implements PlaybackConfigurator {
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
  bool requiresExplicitInitialSeek(String mediaUrl) => false;

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
