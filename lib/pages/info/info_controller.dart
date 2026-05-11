import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_interest.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/pages/info/rating_review_dialog.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/modules/staff/staff_item.dart';

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

  Future<void> queryBangumiInfoByID(int id, {String type = "init"}) async {
    isLoading = true;
    try {
      final value = await BangumiApi.getBangumiInfoByID(id);
      if (value != null) {
        if (type == "init") {
          bangumiItem = value;
          _fillInterestIfAbsentFromPersisted(bangumiItem.id);
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
          if (value.interest != null) {
            bangumiItem.interest = value.interest;
          } else {
            _fillInterestIfAbsentFromPersisted(bangumiItem.id);
          }
        }
        await collectController.updateLocalCollect(bangumiItem);
      }
    } finally {
      isLoading = false;
    }
  }

  void mergePersistedInterestIfAbsent() {
    _fillInterestIfAbsentFromPersisted(bangumiItem.id);
  }

  void _fillInterestIfAbsentFromPersisted(int id) {
    if (bangumiItem.interest != null) return;
    final stored = collectController.getCollectibleBangumiItem(id)?.interest;
    if (stored != null) {
      bangumiItem.interest = stored;
    }
  }

  Future<void> queryBangumiCommentsByID(int id, {int offset = 0}) async {
    if (offset == 0) {
      commentsList.clear();
    }
    await BangumiApi.getBangumiCommentsByID(id, offset: offset).then((value) {
      commentsList.addAll(value.commentList);
    });
    KazumiLogger().i(
        'InfoController: loaded comments list length ${commentsList.length}');
  }

  Future<void> queryBangumiCharactersByID(int id) async {
    characterList.clear();
    await BangumiApi.getCharatersByBangumiID(id).then((value) {
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
    KazumiLogger().i(
        'InfoController: loaded character list length ${characterList.length}');
  }

  Future<void> queryBangumiStaffsByID(int id) async {
    staffList.clear();
    await BangumiApi.getBangumiStaffByID(id).then((value) {
      staffList.addAll(value.data);
    });
    KazumiLogger()
        .i('InfoController: loaded staff list length ${staffList.length}');
  }

  Future<void> rateBangumi(RatingReviewResult data) async {
    final trimmedComment = data.comment.trim();
    if (await BangumiApi.addOrUpdateBangumiEvaluationBySubjectID(
      bangumiItem.id,
      comment: trimmedComment.isNotEmpty ? trimmedComment : null,
      rate: data.score > 0 ? data.score : 0,
      tags: data.tags.isNotEmpty ? data.tags : null,
      private: data.private,
    )) {
      bangumiItem.interest = BangumiInterest.mergeLocalSubmission(
        previous: bangumiItem.interest,
        rate: data.score,
        comment: trimmedComment,
        tags: data.tags,
        private: data.private,
      );
      await collectController.updateLocalCollect(bangumiItem);
      await queryBangumiInfoByID(bangumiItem.id, type: "update");
    }
  }
}
