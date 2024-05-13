import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/plugins/plugins_module.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:mobx/mobx.dart';

part 'video_controller.g.dart';

class VideoPageController = _VideoPageController with _$VideoPageController;

abstract class _VideoPageController with Store {
  
  
  @observable
  String status = 'loading';

  @observable
  var roadList = ObservableList<Road>();

  late Plugin currentPlugin;

  final PluginsController pluginsController = Modular.get<PluginsController>();

  Future<String> queryVideoUrl(String url) async {
    String videoUrl = '';
    for (Plugin plugin in pluginsController.pluginList) {
      if (plugin.name == currentPlugin.name) {
        videoUrl = await plugin.queryVideoUrl(url);
      }
    }
    return videoUrl;
  }
}
