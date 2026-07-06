import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/widget/image_preview.dart';
import 'package:kazumi/pages/collect/collect_module.dart';
import 'package:kazumi/pages/index_page.dart';
import 'package:kazumi/pages/info/info_module.dart';
import 'package:kazumi/pages/init_page.dart';
import 'package:kazumi/pages/my/my_module.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/popular/popular_module.dart';
import 'package:kazumi/pages/route_error_page.dart';
import 'package:kazumi/pages/search/search_module.dart';
import 'package:kazumi/pages/settings/settings_module.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';
import 'package:kazumi/pages/timeline/timeline_module.dart';
import 'package:kazumi/pages/video/video_module.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/services/shaders/shader_asset_service.dart';

final _tabTransition = CustomTransition(
  duration: const Duration(milliseconds: 70),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(opacity: animation, child: child);
  },
);

final _imagePreviewTransition = CustomTransition(
  duration: const Duration(milliseconds: 220),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(opacity: animation, child: child);
  },
);

final tabModule = createModule(
  path: '/tab',
  register: (c) {
    c
      // Tab state survives tab switches, but is released with the whole shell.
      ..addSingleton<PopularController>(PopularController.new)
      ..addSingleton<TimelineController>(TimelineController.new)
      ..route(
        '/',
        child: (context, state) => const IndexPage(),
        transition: _tabTransition,
        children: (sub) {
          sub
            ..route(
              '/',
              guards: [
                (state) => GStorage.getSetting(SettingsKeys.defaultStartupPage),
              ],
              child: (context, state) => const SizedBox.shrink(),
            )
            ..module(popularModule)
            ..module(timelineModule)
            ..module(collectModule)
            ..module(myModule);
        },
      );
  },
);

final indexModule = createModule(
  register: (c) {
    c
      ..route(
        '/',
        child: (context, state) => InitPage(
          pluginsController: inject<PluginsController>(),
          collectController: inject<CollectController>(),
          shaderAssetService: inject<ShaderAssetService>(),
          myController: inject<MyController>(),
          downloadController: inject<DownloadController>(),
        ),
        transition: TransitionType.none,
      )
      ..route(
        '/error',
        child: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Kazumi')),
          body: const Center(child: Text('初始化失败')),
        ),
      )
      ..module(tabModule)
      ..module(videoModule)
      ..route(
        ImageViewer.routePath,
        child: (context, state) {
          final args = state.arguments;
          if (args is! ImageViewerRouteArgs) {
            return const RouteErrorPage(message: '图片预览参数无效，请返回后重试。');
          }
          return ImageViewer(
            imageUrls: args.imageUrls,
            initialIndex: args.initialIndex,
            heroTag: args.heroTag,
          );
        },
        transition: _imagePreviewTransition,
      )
      ..module(infoModule)
      ..module(settingsModule)
      ..module(searchModule);
  },
);
