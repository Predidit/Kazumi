import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:mobx/mobx.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/modules/comments/comment_item.dart';

part 'info_controller.g.dart';

class InfoController = _InfoController with _$InfoController;

abstract class _InfoController with Store {
  late BangumiItem bangumiItem;

  @observable
  var pluginSearchResponseList = ObservableList<PluginSearchResponse>();

  @observable
  var pluginSearchStatus = ObservableMap<String, String>();

  @observable
  var commentsList = ObservableList<CommentItem>();

  @observable
  var episodeCommentsList = ObservableList<EpisodeCommentItem>();

  /// 移动到 query_manager.dart 以解决可能的内存泄漏
  // querySource(String keyword) async {
  //   final PluginsController pluginsController =
  //       Modular.get<PluginsController>();
  //   pluginSearchResponseList.clear();

  //   for (Plugin plugin in pluginsController.pluginList) {
  //     pluginSearchStatus[plugin.name] = 'pending';
  //   }

  //   var controller = StreamController();
  //   for (Plugin plugin in pluginsController.pluginList) {
  //     plugin.queryBangumi(keyword).then((result) {
  //       pluginSearchStatus[plugin.name] = 'success';
  //       controller.add(result);
  //     }).catchError((error) {
  //       pluginSearchStatus[plugin.name] = 'error';
  //     });
  //   }
  //   await for (var result in controller.stream) {
  //     pluginSearchResponseList.add(result);
  //   }
  // }

  queryBangumiSummaryByID(int id) async {
    await BangumiHTTP.getBangumiSummaryByID(id).then((value) {
      bangumiItem.summary = value;
    });
  }

  queryRoads(String url, String pluginName) async {
    final PluginsController pluginsController =
        Modular.get<PluginsController>();
    final VideoPageController videoPageController =
        Modular.get<VideoPageController>();
    videoPageController.roadList.clear();
    for (Plugin plugin in pluginsController.pluginList) {
      if (plugin.name == pluginName) {
        videoPageController.roadList
            .addAll(await plugin.querychapterRoads(url));
      }
    }
    KazumiLogger()
        .log(Level.info, '播放列表长度 ${videoPageController.roadList.length}');
    KazumiLogger().log(
        Level.info, '第一播放列表选集数 ${videoPageController.roadList[0].data.length}');
  }

  queryBangumiCommentsByID(int id, {int offset = 0}) async {
    if (offset == 0) {
      commentsList.clear();
    }
    await BangumiHTTP.getBangumiCommentsByID(id, offset: offset).then((value) {
      commentsList.addAll(value.commentList);
    });
    KazumiLogger().log(Level.info, '已加载评论列表长度 ${commentsList.length}');
  }

  queryBangumiEpisodeCommentsByID(int id, String episode) async {
    episodeCommentsList.clear();
    final episodeId = await BangumiHTTP.getBangumiEpisodeByID(id, int.parse(episode));
    await BangumiHTTP.getBangumiCommentsByEpisodeID(episodeId).then((value) {
      episodeCommentsList.addAll(value.commentList);
    });
    KazumiLogger().log(Level.info, '已加载评论列表长度 ${episodeCommentsList.length}');
  }
}
