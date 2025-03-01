import 'package:kazumi/pages/index_page.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/router.dart';
import 'package:kazumi/pages/init_page.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/video/video_module.dart';
import 'package:kazumi/pages/info/info_module.dart';
import 'package:kazumi/pages/settings/settings_module.dart';
import 'package:kazumi/shaders/shaders_controller.dart';

class IndexModule extends Module {
  @override
  List<Module> get imports => menu.moduleList;

  @override
  void binds(i) {
    i.addSingleton(PopularController.new);
    i.addSingleton(InfoController.new);
    i.addSingleton(PluginsController.new);
    i.addSingleton(VideoPageController.new);
    i.addSingleton(TimelineController.new);
    i.addSingleton(CollectController.new);
    i.addSingleton(HistoryController.new);
    i.addSingleton(MyController.new);
    i.addSingleton(ShadersController.new);
  }

  @override
  void routes(r) {
    r.child("/",
        child: (_) => const InitPage(),
        children: [
          ChildRoute(
            "/error",
            child: (_) => Scaffold(
              appBar: AppBar(title: const Text("Kazumi")),
              body: const Center(child: Text("初始化失败")),
            ),
          ),
        ],
        transition: TransitionType.noTransition);
    r.child("/tab", child: (_) {
      return const IndexPage();
    }, children: menu.routes, transition: TransitionType.noTransition);
    r.module("/video", module: VideoModule());
    r.module("/info", module: InfoModule());
    r.module("/settings", module: SettingsModule());
  }
}
