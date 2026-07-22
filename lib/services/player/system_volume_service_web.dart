import 'package:kazumi/services/player/system_volume_service_contract.dart';

SystemVolumeService createSystemVolumeService() =>
    const WebSystemVolumeService();

/// Browsers have no permission to control the host device's system volume.
class WebSystemVolumeService implements SystemVolumeService {
  const WebSystemVolumeService();

  @override
  bool get isSupported => false;

  @override
  Future<double?> getVolume() async => null;

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setSystemUiVisible(bool visible) async {}

  @override
  void addListener(SystemVolumeChanged listener) {}

  @override
  void removeListener() {}
}
