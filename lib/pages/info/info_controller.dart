import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_interest.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_relation.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/pages/info/rating_review_dialog.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/modules/staff/staff_item.dart';

part 'info_controller.g.dart';

class InfoController = _InfoController with _$InfoController;

abstract class _InfoController with Store {
  _InfoController(this.collectController);

  final CollectController collectController;
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

  final relationList = <BangumiRelation>[];

  int _relationRequestGeneration = 0;

  bool _isFillingInterestUserProfile = false;

  int _commentsOffset = 0;

  void clearComments() {
    commentsList.clear();
    _commentsOffset = 0;
  }

  Future<bool> fillInterestUserProfileIfNeeded() async {
    final interest = bangumiItem.interest;
    if (interest == null || interest.hasUserProfile) {
      return false;
    }
    if (_isFillingInterestUserProfile) {
      return false;
    }
    _isFillingInterestUserProfile = true;
    try {
      final user = await BangumiApi.getCurrentUser();
      if (user == null) {
        return false;
      }
      bangumiItem.interest = interest.copyWithUser(user: user);
      await collectController.updateLocalCollect(bangumiItem);
      return true;
    } catch (e) {
      KazumiLogger()
          .e('InfoController: failed to fill interest user profile', error: e);
      return false;
    } finally {
      _isFillingInterestUserProfile = false;
    }
  }

  void _removeCurrentUserFromPublicComments() {
    final interest = bangumiItem.interest;
    if (interest == null) return;
    final userId = interest.user?.id;
    if (userId == null) return;
    commentsList.removeWhere((item) => item.user.id == userId);
  }

  Future<void> queryBangumiInfoByID(int id, {String type = "init"}) async {
    isLoading = true;
    try {
      await _updateBangumiInfoByID(id, type: type);
    } finally {
      isLoading = false;
    }
  }

  Future<void> refreshBangumiInfoByID(int id) async {
    await _updateBangumiInfoByID(id, type: "update");
  }

  Future<void> _updateBangumiInfoByID(int id, {required String type}) async {
    final value = await BangumiApi.getBangumiInfoByID(id);
    if (value == null) {
      return;
    }
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
      final incomingInterest = value.interest;
      final previousInterest = bangumiItem.interest;
      if (incomingInterest == null) {
        bangumiItem.interest = null;
      } else if (previousInterest == null || !previousInterest.hasUserProfile) {
        bangumiItem.interest = incomingInterest;
      } else {
        bangumiItem.interest =
            incomingInterest.copyWithUser(user: previousInterest.user);
      }
    }
    await collectController.updateLocalCollect(bangumiItem);
  }

  Future<void> queryBangumiCommentsByID(int id, {bool refresh = true}) async {
    await _updateBangumiCommentsByID(
      id,
      refresh: refresh,
      clearBeforeFetch: true,
    );
  }

  Future<void> _updateBangumiCommentsByID(
    int id, {
    required bool refresh,
    required bool clearBeforeFetch,
  }) async {
    if (refresh) {
      if (clearBeforeFetch) {
        clearComments();
      }
    }
    final offset = refresh ? 0 : _commentsOffset;
    await BangumiApi.getBangumiCommentsByID(id, offset: offset).then((value) {
      if (refresh && !clearBeforeFetch) {
        commentsList = ObservableList<CommentItem>.of(value.commentList);
      } else {
        commentsList.addAll(value.commentList);
      }
      _commentsOffset = refresh
          ? value.commentList.length
          : _commentsOffset + value.commentList.length;
      _removeCurrentUserFromPublicComments();
    });
    KazumiLogger().i(
        'InfoController: loaded comments list length ${commentsList.length}, offset $_commentsOffset');
  }

  Future<void> refreshBangumiCommentsSilently(int id) async {
    if (commentsList.isEmpty) {
      return;
    }
    await _updateBangumiCommentsByID(
      id,
      refresh: true,
      clearBeforeFetch: false,
    );
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

  void clearRelations() {
    _relationRequestGeneration++;
    relationList.clear();
  }

  Future<void> queryBangumiRelationsByID(int id) async {
    final requestGeneration = ++_relationRequestGeneration;
    try {
      final relations = await resolveRelatedAnimeChain(
        currentSubjectId: id,
        fetchRelations: BangumiApi.getBangumiRelationsByID,
      );
      if (!_isCurrentRelationRequest(requestGeneration, id)) {
        return;
      }
      relationList
        ..clear()
        ..addAll(relations);
      KazumiLogger().i(
        'InfoController: loaded related anime list length ${relationList.length}',
      );
    } catch (_) {
      if (_isCurrentRelationRequest(requestGeneration, id)) {
        rethrow;
      }
    }
  }

  bool _isCurrentRelationRequest(int requestGeneration, int subjectId) =>
      requestGeneration == _relationRequestGeneration &&
      bangumiItem.id == subjectId;

  Future<bool> rateBangumi(RatingReviewResult data,
      {required int localType}) async {
    final trimmedComment = data.comment.trim();
    if (await BangumiApi.addOrUpdateBangumiEvaluationBySubjectID(
      bangumiItem.id,
      localType,
      comment: trimmedComment.isNotEmpty ? trimmedComment : null,
      rate: data.score > 0 ? data.score : 0,
      tags: data.tags.isNotEmpty ? data.tags : null,
    )) {
      bangumiItem.interest = BangumiInterest.mergeLocalSubmission(
        previous: bangumiItem.interest,
        rate: data.score,
        comment: trimmedComment,
        tags: data.tags,
      );
      await collectController.updateLocalCollect(bangumiItem);
      await fillInterestUserProfileIfNeeded();
      _removeCurrentUserFromPublicComments();
      await refreshBangumiCommentsSilently(bangumiItem.id);
      await refreshBangumiInfoByID(bangumiItem.id);
      return true;
    }
    return false;
  }
}
