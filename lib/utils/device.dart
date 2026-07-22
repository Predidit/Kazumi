import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<bool> isLowResolution() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
    return false;
  }
  final screenInfo = await getScreenInfo();
  return screenInfo['height']! / screenInfo['ratio']! < 900;
}

Future<Map<String, double>> getScreenInfo() async {
  final mediaQuery = MediaQueryData.fromView(
    WidgetsBinding.instance.platformDispatcher.views.first,
  );
  final screenSize =
      WidgetsBinding.instance.platformDispatcher.displays.first.size;
  return {
    'width': screenSize.width,
    'height': screenSize.height,
    'ratio': mediaQuery.devicePixelRatio,
  };
}

bool isDesktop() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

bool isWideScreen() {
  final mediaQuery = MediaQueryData.fromView(
    WidgetsBinding.instance.platformDispatcher.views.first,
  );
  return mediaQuery.size.shortestSide >= 600 &&
      mediaQuery.size.shortestSide / mediaQuery.size.longestSide >= 9 / 16;
}

bool isTablet() {
  return isWideScreen() && !isDesktop();
}

bool isCompact() {
  return !isDesktop() && !isWideScreen();
}
