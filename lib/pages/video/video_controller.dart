import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/plugins/plugins_module.dart';
import 'package:mobx/mobx.dart';

part 'video_controller.g.dart';

class VideoController = _VideoController with _$VideoController;

abstract class _VideoController with Store {
  @observable
  var roadList = ObservableList<Road>();

  String currentPluginName = '';

  final PluginsController pluginsController = Modular.get<PluginsController>();

  Future<String> queryVideoUrl(String url) async {
    String videoUrl = '';
    for (Plugin plugin in pluginsController.pluginList) {
      if (plugin.name == currentPluginName) {
        videoUrl = await plugin.queryVideoUrl(url);
      }
    }
    return videoUrl;
  }
}
