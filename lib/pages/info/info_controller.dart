import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:mobx/mobx.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/modules/staff/staff_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_subject_relations_item.dart';

part 'info_controller.g.dart';

class InfoController = _InfoController with _$InfoController;

abstract class _InfoController with Store {
  final CollectController collectController = Modular.get<CollectController>();
  late BangumiItem bangumiItem;

  @observable
  bool isLoading = false;

  @observable
  var pluginSearchResponseList = ObservableList<PluginSearchResponse>();

  @observable
  var pluginSearchStatus = ObservableMap<String, String>();

  @observable
  var commentsList = ObservableList<CommentItem>();

  @observable
  var characterList = ObservableList<CharacterItem>();

  @observable
  var staffList = ObservableList<StaffFullItem>();

  @observable
  var bangumiSubjectRelationItem = ObservableList<BangumiSubjectRelationItem>();

  Future<void> queryBangumiInfoByID(int id, {String type = "init"}) async {
    isLoading = true;
    await BangumiHTTP.getBangumiInfoByID(id).then((value) {
      if (value != null) {
        if (type == "init") {
          bangumiItem = value;
        } else {
          bangumiItem.summary = value.summary;
          bangumiItem.tags = value.tags;
          bangumiItem.rank = value.rank;
          bangumiItem.airDate = value.airDate;
          bangumiItem.airWeekday = value.airWeekday;
          bangumiItem.alias = value.alias;
          bangumiItem.ratingScore = value.ratingScore;
          bangumiItem.votes = value.votes;
          bangumiItem.votesCount = value.votesCount;
        }
        collectController.updateLocalCollect(bangumiItem);
        isLoading = false;
      }
    });
  }

  Future<void> queryBangumiSubjectRelationItemByID(int id) async {
    bangumiSubjectRelationItem.clear();
    await BangumiHTTP.getRelationById(id).then((v) {
      bangumiSubjectRelationItem.addAll(v);
    });
    KazumiLogger()
        .log(Level.info, '已加载关联列表数量 ${bangumiSubjectRelationItem.length}');
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

  Future<void> queryBangumiCharactersByID(int id) async {
    characterList.clear();
    await BangumiHTTP.getCharatersByBangumiID(id).then((value) {
      characterList.addAll(value.charactersList);
    });
    Map<String, int> relationValue = {
      '主角': 1,
      '配角': 2,
      '客串': 3,
    };

    try {
      characterList.sort((a, b) {
        int valueA = relationValue[a.relation] ?? 4;
        int valueB = relationValue[b.relation] ?? 4;
        return valueA.compareTo(valueB);
      });
    } catch (e) {
      KazumiDialog.showToast(message: '$e');
    }
    KazumiLogger().log(Level.info, '已加载角色列表长度 ${characterList.length}');
  }

  Future<void> queryBangumiStaffsByID(int id) async {
    staffList.clear();
    await BangumiHTTP.getBangumiStaffByID(id).then((value) {
      staffList.addAll(value.data);
    });
    KazumiLogger().log(Level.info, '已加载制作人员列表长度 ${staffList.length}');
  }
}
