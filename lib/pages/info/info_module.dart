import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/info/info_page.dart';
import 'package:kazumi/pages/route_error_page.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

final infoModule = createModule(
  path: '/info',
  register: (c) {
    c.route(
      '/',
      provide: (s) => s.add<InfoController>(InfoController.new),
      child: (context, state) {
        final bangumiItem = state.arguments;
        if (bangumiItem is! BangumiItem) {
          return const RouteErrorPage(message: '番组详情参数无效，请返回后重新打开。');
        }
        return InfoPage(
          inputBangumiItem: bangumiItem,
          infoController: context.read<InfoController>(),
          videoPageController: inject<VideoPageController>(),
          pluginsController: inject<PluginsController>(),
        );
      },
    );
  },
);
