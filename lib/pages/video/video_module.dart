import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/video/video_page.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/download/download_controller.dart';

final videoModule = createModule(
  path: '/video',
  register: (c) {
    c.route(
      '/',
      provide: (s) => s.add<PlayerController>(PlayerController.new),
      child: (context, state) => VideoPage(
        playerController: context.read<PlayerController>(),
        videoPageController: inject<VideoPageController>(),
        historyController: inject<HistoryController>(),
        downloadController: inject<DownloadController>(),
      ),
    );
  },
);
