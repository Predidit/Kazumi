import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kazumi/services/platform/app_platform.dart';
import 'package:kazumi/services/player/system_volume_service_contract.dart';

SystemVolumeService createSystemVolumeService() =>
    const NativeSystemVolumeService();

/// Native mobile implementation backed by flutter_volume_controller.
///
/// The plugin is deliberately never invoked on desktop platforms, where the
/// media player owns its volume.
class NativeSystemVolumeService implements SystemVolumeService {
  const NativeSystemVolumeService();

  @override
  bool get isSupported => KazumiPlatform.isAndroid || KazumiPlatform.isIOS;

  @override
  Future<double?> getVolume() async {
    if (!isSupported) return null;
    return FlutterVolumeController.getVolume();
  }

  @override
  Future<void> setVolume(double volume) async {
    if (!isSupported) return;
    await FlutterVolumeController.setVolume(
      volume.clamp(0.0, 1.0).toDouble(),
    );
  }

  @override
  Future<void> setSystemUiVisible(bool visible) async {
    if (!isSupported) return;
    await FlutterVolumeController.updateShowSystemUI(visible);
  }

  @override
  void addListener(SystemVolumeChanged listener) {
    if (!isSupported) return;
    FlutterVolumeController.addListener(
      listener,
      category: AudioSessionCategory.playback,
      emitOnStart: false,
    );
  }

  @override
  void removeListener() {
    if (!isSupported) return;
    FlutterVolumeController.removeListener();
  }
}
