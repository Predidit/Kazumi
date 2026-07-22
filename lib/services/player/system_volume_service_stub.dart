import 'package:kazumi/services/player/system_volume_service_contract.dart';

SystemVolumeService createSystemVolumeService() =>
    const UnsupportedSystemVolumeService();

class UnsupportedSystemVolumeService implements SystemVolumeService {
  const UnsupportedSystemVolumeService();

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
