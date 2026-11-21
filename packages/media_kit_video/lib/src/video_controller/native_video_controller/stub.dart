/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'package:media_kit/media_kit.dart';

import 'package:media_kit_video/src/video_controller/platform_video_controller.dart';

import 'dart:async';
import 'package:media_kit_video/src/video_controller/video_adapter.dart';

// Stub declaration for avoiding compilation errors on Dart JS using conditional imports.

class NativeVideoController extends PlatformVideoController {
  static const bool supported = false;
  static Stream<WindowsVideoRenderWarning> get windowsRenderWarnings => const Stream.empty();
  static Future<List<VideoAdapter>> getWindowsRenderAdapters() async => const [];


  NativeVideoController._(
    super.player,
    super.configuration,
  );

  static Future<PlatformVideoController> create(
    Player player,
    VideoControllerConfiguration configuration,
  ) =>
      throw UnimplementedError();

  @override
  Future<void> setSize({int? width, int? height}) => throw UnimplementedError();
}
