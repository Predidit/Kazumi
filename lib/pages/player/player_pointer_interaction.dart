import 'package:flutter/gestures.dart';

const Set<PointerDeviceKind> touchLikePointerKinds = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
};

bool isTouchLikePointer(PointerDeviceKind? pointerKind) {
  return touchLikePointerKinds.contains(pointerKind);
}

Set<PointerDeviceKind>? playerSurfaceDragDevices({required bool isLinux}) {
  return isLinux ? touchLikePointerKinds : null;
}

bool shouldEnablePlayerSurfaceSeek({
  required bool isDesktop,
  required bool isLinux,
  required bool panelLocked,
  required Duration videoDuration,
}) {
  return !panelLocked &&
      videoDuration > Duration.zero &&
      (!isDesktop || isLinux);
}

bool shouldEnablePlayerSurfaceVerticalDrag({required bool isDesktop}) {
  return !isDesktop;
}

Duration horizontalDragSeekTarget({
  required Duration initialPosition,
  required Duration videoDuration,
  required double cumulativeDeltaX,
  required double surfaceWidth,
  Duration maximumSpan = const Duration(seconds: 120),
}) {
  // 边界：任一输入非法即回退到起始位置（仅钳负数），绝不返回负数；
  // 时长/尺寸非法时不改预览，保持调用方现有行为（测试依赖返回 initial）。
  final safeInitialMs =
      initialPosition.inMilliseconds.clamp(0, 1 << 62).toInt();
  final safeInitial = Duration(milliseconds: safeInitialMs);
  if (videoDuration <= Duration.zero ||
      surfaceWidth <= 0 ||
      !surfaceWidth.isFinite ||
      !cumulativeDeltaX.isFinite) {
    return safeInitial;
  }

  final safeMaximumSpan =
      (maximumSpan <= Duration.zero || maximumSpan > const Duration(days: 1))
          ? const Duration(seconds: 120)
          : maximumSpan;
  final span = videoDuration < safeMaximumSpan ? videoDuration : safeMaximumSpan;
  final durationMs = videoDuration.inMilliseconds.clamp(0, 1 << 62).toInt();
  final rawOffset = span.inMilliseconds * cumulativeDeltaX / surfaceWidth;
  if (rawOffset.isNaN) {
    return safeInitial;
  }
  if (rawOffset == double.infinity) {
    return Duration(milliseconds: durationMs);
  }
  if (rawOffset == double.negativeInfinity) {
    return Duration.zero;
  }
  final offsetMilliseconds = rawOffset
      .clamp(-safeInitialMs.toDouble(), (durationMs - safeInitialMs).toDouble())
      .round();
  final targetMilliseconds =
      (safeInitialMs + offsetMilliseconds).clamp(0, durationMs).toInt();
  return Duration(milliseconds: targetMilliseconds);
}

int interactiveSeekDirection({
  required Duration initialPosition,
  required Duration target,
}) {
  return target.compareTo(initialPosition);
}

bool shouldToggleControllerOnPrimaryTap({
  required bool isDesktop,
  required PointerDeviceKind? pointerKind,
}) {
  return !isDesktop || isTouchLikePointer(pointerKind);
}

bool shouldToggleFullscreenOnDoubleTap({
  required bool isDesktop,
  required bool isPip,
  required PointerDeviceKind? pointerKind,
}) {
  return isDesktop && !isPip && !isTouchLikePointer(pointerKind);
}
