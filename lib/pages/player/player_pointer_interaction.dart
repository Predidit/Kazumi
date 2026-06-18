import 'package:flutter/gestures.dart';

bool isTouchLikePointer(PointerDeviceKind? pointerKind) {
  return pointerKind == PointerDeviceKind.touch ||
      pointerKind == PointerDeviceKind.stylus ||
      pointerKind == PointerDeviceKind.invertedStylus;
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
