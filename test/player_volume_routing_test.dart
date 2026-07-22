import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/controller/player_debug_controller.dart';
import 'package:kazumi/pages/player/controller/player_playback_controller.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/services/player/playback_configurator_contract.dart';
import 'package:kazumi/services/player/system_volume_service_contract.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  test('player-owned volume never calls the system volume service', () async {
    final systemVolume = _RecordingSystemVolumeService();
    final controller = PlayerPlaybackController(
      shaderDirectoryPath: () => '',
      debug: PlayerDebugController(),
      videoUrl: () => '',
      platformConfigurator: const _VolumeRoutingConfigurator(
        usePlayerVolume: true,
      ),
      systemVolumeService: systemVolume,
    );

    await controller.syncVolumeToDevice(42);

    expect(systemVolume.setVolumeCalls, 0);
  });

  test('system-owned volume is normalized before delegation', () async {
    final systemVolume = _RecordingSystemVolumeService();
    final controller = PlayerPlaybackController(
      shaderDirectoryPath: () => '',
      debug: PlayerDebugController(),
      videoUrl: () => '',
      platformConfigurator: const _VolumeRoutingConfigurator(
        usePlayerVolume: false,
      ),
      systemVolumeService: systemVolume,
    );

    await controller.syncVolumeToDevice(42);

    expect(systemVolume.setVolumeCalls, 1);
    expect(systemVolume.lastVolume, closeTo(0.42, 0.0001));
  });
}

class _VolumeRoutingConfigurator implements PlaybackConfigurator {
  const _VolumeRoutingConfigurator({required this.usePlayerVolume});

  @override
  final bool usePlayerVolume;

  @override
  bool requiresExplicitInitialSeek(String mediaUrl) => false;

  @override
  Future<SuperResolutionMode?> applySuperResolution(
    Player player,
    SuperResolutionMode mode, {
    required bool Function() isCurrent,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PlaybackPlatformConfiguration?> configurePlayer(
    Player player,
    PlaybackPlatformOptions options, {
    required bool Function() isCurrent,
  }) {
    throw UnimplementedError();
  }

  @override
  Map<String, String> mediaHttpHeaders(Map<String, String> requestedHeaders) =>
      requestedHeaders;

  @override
  bool resolveAutoPlay(bool configuredAutoPlay) => configuredAutoPlay;
}

class _RecordingSystemVolumeService implements SystemVolumeService {
  int setVolumeCalls = 0;
  double? lastVolume;

  @override
  bool get isSupported => true;

  @override
  void addListener(SystemVolumeChanged listener) {}

  @override
  Future<double?> getVolume() async => 0.5;

  @override
  void removeListener() {}

  @override
  Future<void> setSystemUiVisible(bool visible) async {}

  @override
  Future<void> setVolume(double volume) async {
    setVolumeCalls += 1;
    lastVolume = volume;
  }
}
