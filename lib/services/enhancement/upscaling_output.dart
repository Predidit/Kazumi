import 'dart:math' as math;

/// Returns a larger render surface only when it fits the actual viewport and
/// the device's preset budget. Null means use media-kit's original source size.
({int width, int height})? upscalingOutputSize({
  required int sourceWidth,
  required int sourceHeight,
  required double viewportWidth,
  required double viewportHeight,
  required bool enabled,
  bool fill = false,
  required int maximumEdge,
}) {
  if (!enabled ||
      sourceWidth <= 0 ||
      sourceHeight <= 0 ||
      !viewportWidth.isFinite ||
      !viewportHeight.isFinite ||
      viewportWidth <= 0 ||
      viewportHeight <= 0) {
    return null;
  }
  final x = viewportWidth / sourceWidth;
  final y = viewportHeight / sourceHeight;
  final scale = math.min(
    fill ? math.max(x, y) : math.min(x, y),
    maximumEdge / math.max(sourceWidth, sourceHeight),
  );
  if (scale <= 1.03) return null;
  return (
    width: (sourceWidth * scale).round(),
    height: (sourceHeight * scale).round(),
  );
}
