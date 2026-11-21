import 'dart:convert';
import 'dart:io';

import 'package:media_kit/media_kit.dart';

/// Only enhanced builds ship both the patched mpv and the neural video bridge.
abstract final class FrameInterpolation {
  static const bundled = bool.fromEnvironment('KAZUMI_RIFE');
  static bool get platformSupported => Platform.isWindows || Platform.isAndroid;
  static bool get available => bundled && platformSupported;

  static String copyBackDecoder(String decoder) => switch (decoder) {
    'no' => 'no',
    'd3d12va' ||
    'd3d11va' ||
    'dxva2' ||
    'mediacodec' ||
    'nvdec' ||
    'vulkan' => '$decoder-copy',
    _ when decoder.endsWith('-copy') => decoder,
    _ => 'auto-copy',
  };

  static const modelLabel = 'DRBA_Distill lite';
  static const label = 'kazumi-motion';

  static Future<bool> isAttached(NativePlayer player) async =>
      (await player.getProperty('options/vf')).contains('@$label:');
}

enum InterpolationMode {
  off('关闭', '保留原始帧率和动画节奏'),
  efficiency('效率档', '降低推理尺寸；出现卡顿、发热时优先选这档'),
  balanced('均衡档', '兼顾动作平滑度和 GPU 负载'),
  quality('质量档', '动画优先使用三帧推理，分别估计角色和背景的运动');

  const InterpolationMode(this.label, this.description);
  final String label;
  final String description;

  static InterpolationMode fromKey(Object? key) =>
      values.where((x) => x.name == key).firstOrNull ?? off;
}

class InterpolationOptions {
  const InterpolationOptions({
    this.factor,
    this.maximumEdge,
    this.maximumFps,
    this.maximumGap,
    this.sceneThreshold,
    this.staticThreshold,
    this.cpu = false,
    this.threads = 4,
    this.realtimeGuard = true,
  });

  final int? factor, maximumEdge, maximumFps;
  final double? maximumGap, sceneThreshold, staticThreshold;
  final bool cpu, realtimeGuard;
  final int threads;

  factory InterpolationOptions.decode(String source) {
    try {
      final data = jsonDecode(source);
      if (data is! Map<String, dynamic>) return const InterpolationOptions();
      int? integer(String key, int lo, int hi) => switch (data[key]) {
        final int value when value >= lo && value <= hi => value,
        _ => null,
      };
      double? decimal(String key, double lo, double hi) => switch (data[key]) {
        final num value when value.isFinite && value >= lo && value <= hi =>
          value.toDouble(),
        _ => null,
      };
      bool? flag(String key) => data[key] is bool ? data[key] as bool : null;
      return InterpolationOptions(
        factor: integer('factor', 2, 4),
        maximumEdge: integer('maximumEdge', 320, 4096),
        maximumFps: integer('maximumFps', 24, 144),
        maximumGap: decimal('maximumGap', 0.05, 0.5),
        sceneThreshold: decimal('sceneThreshold', 0, 1),
        staticThreshold: decimal('staticThreshold', 0, 0.1),
        cpu: flag('cpu') ?? false,
        threads: integer('threads', 1, 16) ?? 4,
        realtimeGuard: flag('realtimeGuard') ?? true,
      );
    } on FormatException {
      return const InterpolationOptions();
    }
  }

  Map<String, Object?> get values => {
    'factor': factor,
    'maximumEdge': maximumEdge,
    'maximumFps': maximumFps,
    'maximumGap': maximumGap,
    'sceneThreshold': sceneThreshold,
    'staticThreshold': staticThreshold,
    'cpu': cpu,
    'threads': threads,
    'realtimeGuard': realtimeGuard,
  };

  InterpolationPlan? plan(
    InterpolationMode mode, {
    required bool mobile,
    bool highMemoryGpu = false,
  }) {
    if (mode == InterpolationMode.off) return null;
    final edges = cpu
        ? const [384, 384, 384]
        : mobile
        ? const [480, 640, 960]
        : highMemoryGpu
        ? const [640, 1280, 1920]
        : const [480, 832, 1280];
    final edge = switch (mode) {
      InterpolationMode.efficiency => edges[0],
      InterpolationMode.balanced => edges[1],
      _ => edges[2],
    };
    return InterpolationPlan(
      factor ?? 2,
      maximumEdge ?? edge,
      maximumFps ?? 60,
      maximumGap ?? 0.1,
      sceneThreshold ?? 0.18,
      staticThreshold ?? 0.002,
      cpu,
      threads,
      realtimeGuard,
    );
  }
}

class InterpolationPlan {
  const InterpolationPlan(
    this.factor,
    this.maximumEdge,
    this.maximumFps,
    this.maximumGap,
    this.sceneThreshold,
    this.staticThreshold,
    this.cpu,
    this.threads,
    this.realtimeGuard,
  );

  final int factor, maximumEdge, maximumFps, threads;
  final double maximumGap, sceneThreshold, staticThreshold;
  final bool cpu, realtimeGuard;

  /// mpv's fixed-length `%n%value` avoids filter syntax ambiguity, including
  /// colons/semicolons/Unicode in profile paths or DXGI LUIDs. No command shell.
  static String quote(String value) => '%${utf8.encode(value).length}%$value';

  String filter(String modelDirectory, {String? device, int? startingEdge}) {
    String flag(bool enabled) => enabled ? 'yes' : 'no';
    final args = [
      'model=${quote(modelDirectory)}',
      if (!cpu && device != null && device.isNotEmpty)
        'device=${quote(device)}',
      'factor=$factor',
      'max-edge=$maximumEdge',
      if (realtimeGuard && startingEdge != null && startingEdge < maximumEdge)
        'start-edge=$startingEdge',
      'max-fps=$maximumFps',
      'max-gap=$maximumGap',
      'scene-threshold=$sceneThreshold',
      'static-threshold=$staticThreshold',
      'cpu=${flag(cpu)}',
      'threads=$threads',
      'realtime-guard=${flag(realtimeGuard)}',
    ];
    return '@${FrameInterpolation.label}:kazumi-drba=${args.join(':')}';
  }
}
