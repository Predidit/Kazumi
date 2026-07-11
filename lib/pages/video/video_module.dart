import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/route_error_page.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/video/video_page.dart';
import 'package:kazumi/pages/video/video_playback_args.dart';

final videoModule = createModule(
  path: '/video',
  register: (c) {
    c.route(
      '/',
      provide: (s) => s
        ..add<VideoPageController>(VideoPageController.new)
        ..add<PlayerController>(PlayerController.new),
      child: (context, state) {
        final args = state.arguments;
        if (args is! VideoPlaybackArgs) {
          return const RouteErrorPage(message: '播放参数无效，请返回后重试。');
        }
        return VideoPage(
          args: args,
          playerController: context.read<PlayerController>(),
          videoPageController: context.read<VideoPageController>(),
          historyController: inject<HistoryController>(),
          downloadController: inject<DownloadController>(),
        );
      },
    );
  },
);
