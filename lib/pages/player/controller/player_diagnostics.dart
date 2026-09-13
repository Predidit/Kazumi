import 'dart:convert';

final class PlayerDiagnosticsSnapshot {
  const PlayerDiagnosticsSnapshot({
    required this.hardwareAccelerationEnabled,
    required this.configuredHardwareDecoder,
    required this.activeHardwareDecoder,
    required this.hardwareInterop,
    required this.videoOutput,
    required this.gpuContext,
    required this.videoCodec,
    required this.videoProfile,
    required this.audioCodec,
    required this.pixelFormat,
    required this.hardwarePixelFormat,
    required this.estimatedFps,
    required this.audioOutput,
    required this.audioInputSampleRate,
    required this.audioOutputSampleRate,
    required this.avSync,
    required this.audioDelay,
    required this.totalAvSyncChange,
    required this.mistimedFrames,
    required this.delayedFrames,
    required this.vsyncRatio,
    required this.cacheDuration,
    required this.outputDroppedFrames,
    required this.decoderDroppedFrames,
  });

  factory PlayerDiagnosticsSnapshot.fromProperties(
    Map<String, String> properties, {
    required bool hardwareAccelerationEnabled,
    required String configuredHardwareDecoder,
  }) {
    final tracks = _selectedTrackCodecs(properties['track-list'] ?? '');
    return PlayerDiagnosticsSnapshot(
      hardwareAccelerationEnabled: hardwareAccelerationEnabled,
      configuredHardwareDecoder: configuredHardwareDecoder,
      activeHardwareDecoder: properties['hwdec-current'] ?? '',
      hardwareInterop: properties['hwdec-interop'] ?? '',
      videoOutput: properties['current-vo'] ?? '',
      gpuContext: properties['current-gpu-context'] ?? '',
      videoCodec: tracks.videoCodec,
      videoProfile: tracks.videoProfile,
      audioCodec: tracks.audioCodec,
      pixelFormat: properties['video-params/pixelformat'] ?? '',
      hardwarePixelFormat: properties['video-params/hw-pixelformat'] ?? '',
      estimatedFps: properties['estimated-vf-fps'] ?? '',
      audioOutput: properties['current-ao'] ?? '',
      audioInputSampleRate: properties['audio-params/samplerate'] ?? '',
      audioOutputSampleRate: properties['audio-out-params/samplerate'] ?? '',
      avSync: properties['avsync'] ?? '',
      audioDelay: properties['audio-delay'] ?? '',
      totalAvSyncChange: properties['total-avsync-change'] ?? '',
      mistimedFrames: properties['mistimed-frame-count'] ?? '',
      delayedFrames: properties['vo-delayed-frame-count'] ?? '',
      vsyncRatio: properties['vsync-ratio'] ?? '',
      cacheDuration: properties['demuxer-cache-duration'] ?? '',
      outputDroppedFrames: properties['frame-drop-count'] ?? '',
      decoderDroppedFrames: properties['decoder-frame-drop-count'] ?? '',
    );
  }

  final bool hardwareAccelerationEnabled;
  final String configuredHardwareDecoder;
  final String activeHardwareDecoder;
  final String hardwareInterop;
  final String videoOutput;
  final String gpuContext;
  final String videoCodec;
  final String videoProfile;
  final String audioCodec;
  final String pixelFormat;
  final String hardwarePixelFormat;
  final String estimatedFps;
  final String audioOutput;
  final String audioInputSampleRate;
  final String audioOutputSampleRate;
  final String avSync;
  final String audioDelay;
  final String totalAvSyncChange;
  final String mistimedFrames;
  final String delayedFrames;
  final String vsyncRatio;
  final String cacheDuration;
  final String outputDroppedFrames;
  final String decoderDroppedFrames;

  String get decodeRouteSummary {
    if (!hardwareAccelerationEnabled || configuredHardwareDecoder == 'no') {
      return '软件解码 · 硬解已关闭';
    }
    if (activeHardwareDecoder.isEmpty) {
      return '正在检测 · 配置 $configuredHardwareDecoder';
    }
    if (activeHardwareDecoder == 'no') {
      return '软件解码 · 已从 $configuredHardwareDecoder 回退';
    }
    final decoder = switch (activeHardwareDecoder) {
      'mediacodec' => 'MediaCodec',
      'mediacodec-copy' => 'MediaCodec (copy)',
      _ => activeHardwareDecoder,
    };
    final interop = hardwareInterop.isEmpty ? '' : ' · $hardwareInterop';
    return '$decoder 通路$interop · 配置 $configuredHardwareDecoder';
  }

  String get outputSummary {
    final values = [videoOutput, gpuContext]
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return values.isEmpty ? '暂无数据' : values.join(' · ');
  }

  String get streamSummary {
    final codec =
        [videoCodec, videoProfile].where((value) => value.isNotEmpty).join(' ');
    final pixel = hardwarePixelFormat.isNotEmpty
        ? '$pixelFormat / $hardwarePixelFormat'
        : pixelFormat;
    final fps = _formatDecimal(estimatedFps, suffix: ' fps');
    final values = [codec, pixel, fps]
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return values.isEmpty ? '暂无数据' : values.join(' · ');
  }

  String get playbackHealthSummary {
    final outputDrops =
        outputDroppedFrames.isEmpty ? '—' : _formatInteger(outputDroppedFrames);
    final decoderDrops = decoderDroppedFrames.isEmpty
        ? '—'
        : _formatInteger(decoderDroppedFrames);
    final cache = _formatDecimal(cacheDuration, suffix: ' 秒');
    final mistimed =
        mistimedFrames.isEmpty ? '—' : _formatInteger(mistimedFrames);
    final delayed = delayedFrames.isEmpty ? '—' : _formatInteger(delayedFrames);
    return '输出丢帧 $outputDrops · 解码丢帧 $decoderDrops'
        ' · 误时 $mistimed · 延迟 $delayed'
        '${cache.isEmpty ? '' : ' · 缓存 $cache'}';
  }

  String get audioClockSummary {
    final rates = [
      if (audioInputSampleRate.isNotEmpty)
        '输入 ${_formatRate(audioInputSampleRate)}',
      if (audioOutputSampleRate.isNotEmpty)
        '输出 ${_formatRate(audioOutputSampleRate)}',
    ];
    final sync = _formatMilliseconds(avSync);
    final delay = _formatMilliseconds(audioDelay);
    final total = _formatMilliseconds(totalAvSyncChange);
    final values = [
      if (audioOutput.isNotEmpty) audioOutput,
      ...rates,
      if (sync.isNotEmpty) 'A/V $sync',
      if (delay.isNotEmpty) '音频延迟 $delay',
      if (total.isNotEmpty) '累计校正 $total',
      if (vsyncRatio.isNotEmpty) 'VSync ${_formatPlain(vsyncRatio)}',
    ];
    return values.isEmpty ? '暂无数据' : values.join(' · ');
  }

  static String _formatInteger(String value) {
    return int.tryParse(value)?.toString() ?? value;
  }

  static String _formatDecimal(String value, {required String suffix}) {
    final parsed = double.tryParse(value);
    if (parsed == null) return value.isEmpty ? '' : '$value$suffix';
    final formatted = parsed == parsed.roundToDouble()
        ? parsed.toStringAsFixed(0)
        : parsed.toStringAsFixed(2);
    return '$formatted$suffix';
  }

  static String _formatRate(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) return '$value Hz';
    return '${parsed.round()} Hz';
  }

  static String _formatMilliseconds(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) return value.isEmpty ? '' : value;
    final milliseconds = parsed * 1000;
    return '${milliseconds.toStringAsFixed(milliseconds.abs() < 10 ? 2 : 1)} ms';
  }

  static String _formatPlain(String value) {
    final parsed = double.tryParse(value);
    return parsed?.toStringAsFixed(4) ?? value;
  }
}

({String videoCodec, String videoProfile, String audioCodec})
    _selectedTrackCodecs(String raw) {
  if (raw.isEmpty) {
    return (videoCodec: '', videoProfile: '', audioCodec: '');
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return (videoCodec: '', videoProfile: '', audioCodec: '');
    }
    String videoCodec = '';
    String videoProfile = '';
    String audioCodec = '';
    for (final item in decoded) {
      if (item is! Map) continue;
      final selected = item['selected'];
      if (selected != true && selected != 'yes') continue;
      final type = item['type']?.toString();
      if (type == 'video') {
        videoCodec = item['codec']?.toString() ?? '';
        videoProfile = item['codec-profile']?.toString() ?? '';
      } else if (type == 'audio') {
        audioCodec = item['codec']?.toString() ?? '';
      }
    }
    return (
      videoCodec: videoCodec,
      videoProfile: videoProfile,
      audioCodec: audioCodec,
    );
  } catch (_) {
    return (videoCodec: '', videoProfile: '', audioCodec: '');
  }
}
