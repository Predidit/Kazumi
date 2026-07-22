import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/system_volume_service_native.dart';
import 'package:kazumi/services/player/system_volume_service_web.dart';

void main() {
  test('Web system volume service is unsupported and safely does nothing',
      () async {
    const service = WebSystemVolumeService();
    var listenerCalled = false;

    expect(service.isSupported, isFalse);
    expect(await service.getVolume(), isNull);

    service.addListener((_) => listenerCalled = true);
    await service.setVolume(0.5);
    await service.setSystemUiVisible(false);
    service.removeListener();

    expect(listenerCalled, isFalse);
  });

  test('desktop native service does not invoke the mobile volume plugin',
      () async {
    const service = NativeSystemVolumeService();

    expect(service.isSupported, isFalse);
    expect(await service.getVolume(), isNull);
    await service.setVolume(0.5);
    await service.setSystemUiVisible(false);
    service.addListener((_) {});
    service.removeListener();
  });
}
