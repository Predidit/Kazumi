import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
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
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';

part 'info_controller.g.dart';

class InfoController = _InfoController with _$InfoController;

abstract class _InfoController with Store {
  final CollectController collectController = Modular.get<CollectController>();
  late BangumiItem bangumiItem;
  EpisodeInfo episodeInfo = EpisodeInfo.fromTemplate();

  @observable
  var pluginSearchResponseList = ObservableList<PluginSearchResponse>();

  @observable
  var pluginSearchStatus = ObservableMap<String, String>();

  @observable
  var commentsList = ObservableList<CommentItem>();

  @observable
  var episodeCommentsList = ObservableList<EpisodeCommentItem>();
  
  @observable
  var characterList = ObservableList<CharacterItem>();

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

  Future<void> queryBangumiInfoByID(int id, {String type = "init"}) async {
    await BangumiHTTP.getBangumiInfoByID(id).then((value) {
      if (value != null) {
        if (type == "init") {
          bangumiItem = value;
        } else {
          bangumiItem.summary = value.summary;
          bangumiItem.tags = value.tags;
          bangumiItem.rank = value.rank;
        }
        collectController.updateLocalCollect(bangumiItem);
      }
    });
  }

  Future<void> queryRoads(String url, String pluginName) async {
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

  Future<void> queryBangumiCommentsByID(int id, {int offset = 0}) async {
    if (offset == 0) {
      commentsList.clear();
    }
    await BangumiHTTP.getBangumiCommentsByID(id, offset: offset).then((value) {
      commentsList.addAll(value.commentList);
    });
    KazumiLogger().log(Level.info, '已加载评论列表长度 ${commentsList.length}');
  }

  Future<void> queryBangumiEpisodeCommentsByID(int id, int episode) async {
    episodeCommentsList.clear();
    episodeInfo = await BangumiHTTP.getBangumiEpisodeByID(id, episode);
    await BangumiHTTP.getBangumiCommentsByEpisodeID(episodeInfo.id).then((value) {
      episodeCommentsList.addAll(value.commentList);
    });
    KazumiLogger().log(Level.info, '已加载评论列表长度 ${episodeCommentsList.length}');
  }
  
  Future<void> queryBangumiCharactersByID(int id) async {
    characterList.clear();
    await BangumiHTTP.getCharatersByID(id).then((value) {
      characterList.addAll(value.characterList);
    });
    Map<String, int> relationValue = {
      '主角': 1,
      '配角': 2,
      '客串': 3,
      '未知': 4,
    };
    try {
      characterList.sort((a, b) =>
          relationValue[a.relation]!.compareTo(relationValue[b.relation]!));
    } catch (e) {
      KazumiDialog.showToast(message: '$e');
    }
    KazumiLogger().log(Level.info, '已加载角色列表长度 ${characterList.length}');
  }
}
