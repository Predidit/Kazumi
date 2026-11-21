import 'dart:io';

import 'package:kazumi/services/enhancement/frame_interpolation.dart';
import 'package:kazumi/services/enhancement/video_gpu.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Conservative starting points, not a performance benchmark. Mobile GPU
/// memory is usually shared; do not infer its throughput from reported RAM.
class VideoEnhancementAdvice {
  const VideoEnhancementAdvice({
    required this.mobile,
    this.adapter,
    required this.cpuCount,
  });

  final bool mobile;
  final VideoAdapter? adapter;
  final int cpuCount;

  static Future<VideoEnhancementAdvice> detect() async {
    List<VideoAdapter> adapters = [];
    if (VideoGpu.supported) {
      try {
        adapters = await VideoGpu.enumerate().timeout(
          const Duration(seconds: 4),
        );
      } catch (_) {
        // The settings are still usable when enumeration is unavailable.
      }
    }
    return fromAdapters(
      mobile: Platform.isAndroid || Platform.isIOS,
      cpuCount: Platform.numberOfProcessors,
      adapters: adapters,
      selectedId: VideoGpu.supported ? VideoGpu.selection : '',
    );
  }

  static VideoEnhancementAdvice fromAdapters({
    required bool mobile,
    required int cpuCount,
    required List<VideoAdapter> adapters,
    required String selectedId,
  }) {
    final selected = adapters.where((gpu) => gpu.id == selectedId).firstOrNull;
    final conservative = adapters.fold<VideoAdapter?>(
      null,
      (result, gpu) =>
          result == null || (gpu.memoryMiB ?? 0) < (result.memoryMiB ?? 0)
          ? gpu
          : result,
    );
    return VideoEnhancementAdvice(
      mobile: mobile,
      cpuCount: cpuCount,
      adapter: selected ?? conservative,
    );
  }

  bool get ampleDedicatedMemory => !mobile && (adapter?.memoryMiB ?? 0) >= 6144;
  String get deviceLabel => adapter == null
      ? '未检测到可选 GPU · $cpuCount 逻辑线程'
      : '${adapter!.name}${!mobile && (adapter!.memoryMiB ?? 0) > 0 ? ' · ${adapter!.memoryMiB} MiB 独立显存' : ''}';

  InterpolationPlan interpolation(InterpolationMode tier, {bool cpu = false}) =>
      InterpolationOptions(cpu: cpu, threads: cpuCount.clamp(1, 4)).plan(
        tier == InterpolationMode.off ? InterpolationMode.efficiency : tier,
        mobile: mobile,
        highMemoryGpu: ampleDedicatedMemory,
      )!;

  /// Applies only interpolation parameters, never silently enabling the filter.
  Map<String, Object?> recommendedInterpolation(InterpolationMode tier) {
    final plan = interpolation(tier);
    return {
      'factor': plan.factor,
      'maximumEdge': plan.maximumEdge,
      'maximumFps': plan.maximumFps,
      'maximumGap': plan.maximumGap,
      'sceneThreshold': plan.sceneThreshold,
      'staticThreshold': plan.staticThreshold,
      'realtimeGuard': true,
      'cpu': false,
      'threads': cpuCount.clamp(1, 4),
    };
  }
}
