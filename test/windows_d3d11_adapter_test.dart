import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  test('Windows adapter data exposes the stable ID and VRAM', () {
    final adapter = WindowsD3D11Adapter.fromMap({
      'id': '00000000:00001234',
      'name': 'NVIDIA Tesla M40',
      'dedicatedVideoMemoryMb': 24576,
    });

    expect(adapter.id, '00000000:00001234');
    expect(adapter.displayName, 'NVIDIA Tesla M40 (24576 MB)');
  });

  test('video configuration preserves the selected Windows adapter', () {
    const config = VideoControllerConfiguration(
      windowsD3D11Adapter: '00000000:00001234',
    );
    final updated = config.copyWith(width: 1280);

    expect(updated.windowsD3D11Adapter, '00000000:00001234');
    expect(updated.width, 1280);
    expect(const VideoControllerConfiguration().windowsD3D11Adapter, 'auto');
  });

  test('native renderer failures are exposed as stream events', () async {
    final errorEvent = MediaKitVideo.windowsVideoOutputErrors.first;
    MediaKitVideo.reportWindowsVideoOutputError({
      'handle': 42,
      'message': 'cross-adapter transfer failed',
    });

    final error = await errorEvent;
    expect(error.playerHandle, 42);
    expect(error.message, 'cross-adapter transfer failed');
  });
}
