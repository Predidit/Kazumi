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
  if (videoDuration <= Duration.zero ||
      surfaceWidth <= 0 ||
      !surfaceWidth.isFinite ||
      !cumulativeDeltaX.isFinite) {
    return initialPosition;
  }

  final span = videoDuration < maximumSpan ? videoDuration : maximumSpan;
  final offsetMilliseconds =
      (span.inMilliseconds * cumulativeDeltaX / surfaceWidth).round();
  final targetMilliseconds =
      initialPosition.inMilliseconds + offsetMilliseconds;
  return Duration(
    milliseconds:
        targetMilliseconds.clamp(0, videoDuration.inMilliseconds).toInt(),
  );
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
