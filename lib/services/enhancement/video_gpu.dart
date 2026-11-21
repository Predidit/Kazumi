import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoGpu {
  static const _androidChannel = MethodChannel('com.predidit.kazumi/intent');

  static bool get supported => Platform.isWindows || Platform.isAndroid;

  static SettingKey<String> get setting => Platform.isWindows
      ? SettingsKeys.windowsVideoGpu
      : SettingsKeys.androidVideoGpu;

  static String get selection => GStorage.getSetting(setting);

  static Future<List<VideoAdapter>> enumerate() async {
    if (Platform.isWindows) return VideoController.getWindowsRenderAdapters();
    if (!Platform.isAndroid) return const [];
    final raw = await _androidChannel.invokeListMethod<Object>(
      'getVideoGpuAdapters',
    );
    return [
      for (final value in raw ?? const [])
        if (VideoAdapter.tryParse(value) case final adapter?) adapter,
    ];
  }
}

/// Neural filters can use Vulkan compute with OpenGL rendering. MediaCodec's embedded
/// output bypasses both enhancement stages.
({
  String renderer,
  String? renderDevice,
  String? interpolationDevice,
  bool unavailable,
})
androidGpuPlan({
  required String rendererSetting,
  required int sdkVersion,
  required String selectedDevice,
  required Iterable<VideoAdapter> available,
}) {
  final requested =
      selectedDevice.isNotEmpty && rendererSetting != 'mediacodec_embed';
  final device = requested && available.any((gpu) => gpu.id == selectedDevice)
      ? selectedDevice
      : null;
  final preferVulkan =
      device != null || (sdkVersion >= 34 && available.isNotEmpty);
  final renderer = rendererSetting == 'auto'
      ? (preferVulkan ? 'gpu-next' : 'gpu')
      : rendererSetting;
  return (
    renderer: renderer,
    renderDevice: renderer == 'gpu-next' ? device : null,
    interpolationDevice: device,
    unavailable: requested && device == null,
  );
}
