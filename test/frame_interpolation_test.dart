import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/enhancement/frame_interpolation.dart';
import 'package:kazumi/services/enhancement/video_enhancement_advice.dart';

void main() {
  test('Budget warning identifies the backend and actual frame timings', () {
    const log =
        'KAZUMI_DRBA_OVER_BUDGET: keeping source cadence '
        '(59.1 ms work for 41.7 ms gap at 320 px)';
    final cpu = FrameInterpolation.budgetWarning(log, cpu: true);
    expect(cpu, startsWith('CPU 插帧'));
    expect(cpu, contains('59.1 ms'));
    expect(cpu, contains('原帧间隔 41.7 ms'));
    expect(cpu, contains('320 px'));
    expect(
      FrameInterpolation.budgetWarning(log, cpu: false),
      startsWith('Vulkan GPU 插帧'),
    );
  });

  test('Unstructured budget warnings are distinct from inference errors', () {
    expect(
      FrameInterpolation.budgetWarning(
        'KAZUMI_DRBA_OVER_BUDGET: keeping source cadence',
        cpu: true,
      ),
      contains('已保留原始帧率'),
    );
    expect(
      FrameInterpolation.budgetWarning(
        'KAZUMI_DRBA_INFERENCE_FAILED: 4',
        cpu: true,
      ),
      isNull,
    );
  });

  test('Recommended parameters preserve the selected backend', () {
    const advice = VideoEnhancementAdvice(mobile: true, cpuCount: 8);
    final cpu = advice.recommendedInterpolation(
      InterpolationMode.efficiency,
      cpu: true,
    );
    final gpu = advice.recommendedInterpolation(
      InterpolationMode.efficiency,
      cpu: false,
    );
    expect(cpu['cpu'], isTrue);
    expect(cpu['maximumEdge'], 384);
    expect(gpu['cpu'], isFalse);
    expect(gpu['maximumEdge'], 480);
  });
}
