import 'package:kazumi/modules/bangumi/bangumi_interest.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_relation.dart';
import 'package:kazumi/modules/bangumi/bangumi_review.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/modules/staff/staff_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/async_session.dart';
import 'package:mobx/mobx.dart';

part 'info_controller.g.dart';

enum InfoLoadStatus { idle, loading, loaded, failed }

class InfoController = _InfoController with _$InfoController;

abstract class _InfoController with Store {
  _InfoController(this.collectController);

  final CollectController collectController;
  final _lifetime = AsyncSessionOwner();
  final _infoRequests = AsyncSessionOwner();
  final _commentRequests = AsyncSessionOwner();
  final _characterRequests = AsyncSessionOwner();
  final _staffRequests = AsyncSessionOwner();
  final _relationRequests = AsyncSessionOwner();
  late AsyncSession _subject;
  bool _isFillingInterestUserProfile = false;
  int _commentsOffset = 0;

  @readonly
  late BangumiItem _bangumiItem;

  @readonly
  InfoLoadStatus _infoStatus = InfoLoadStatus.idle;

  @readonly
  InfoLoadStatus _commentsStatus = InfoLoadStatus.idle;

  @readonly
  InfoLoadStatus _charactersStatus = InfoLoadStatus.idle;

  @readonly
  InfoLoadStatus _staffStatus = InfoLoadStatus.idle;

  @readonly
  InfoLoadStatus _relationsStatus = InfoLoadStatus.idle;

  @readonly
  List<CommentItem> _commentsList = const [];

  @readonly
  List<CharacterItem> _characterList = const [];

  @readonly
  List<StaffFullItem> _staffList = const [];

  @readonly
  List<BangumiRelation> _relationList = const [];

  @observable
  var pluginSearchResponseList = ObservableList<PluginSearchResponse>();

  @observable
  var pluginSearchStatus = ObservableMap<String, PluginSearchStatus>();

  @action
  void initialize(BangumiItem item) {
    _subject = _lifetime.begin();
    for (final owner in _requests) {
      owner.cancel();
    }
    _bangumiItem = item;
    _commentsOffset = 0;
    _isFillingInterestUserProfile = false;
    _infoStatus = _commentsStatus = _charactersStatus =
        _staffStatus = _relationsStatus = InfoLoadStatus.idle;
    _commentsList = const [];
    _characterList = const [];
    _staffList = const [];
    _relationList = const [];
    pluginSearchResponseList.clear();
    pluginSearchStatus.clear();
  }

  Iterable<AsyncSessionOwner> get _requests => [
        _infoRequests,
        _commentRequests,
        _characterRequests,
        _staffRequests,
        _relationRequests,
      ];

  void dispose() {
    _lifetime.close();
    for (final owner in _requests) {
      owner.close();
    }
  }

  @action
  Future<void> loadInfo() async {
    if (_lifetime.isClosed) return;
    final request = _infoRequests.begin();
    _infoStatus = InfoLoadStatus.loading;
    try {
      final value = await BangumiApi.getBangumiInfoByID(_bangumiItem.id);
      if (request.isStale) return;
      if (value == null) throw StateError('Missing subject details');
      final previousInterest = _bangumiItem.interest;
      // Preserve identity and image URLs used by the active Hero flight.
      _bangumiItem = _bangumiItem.copy()
        ..summary = value.summary
        ..tags = value.tags
        ..rank = value.rank
        ..airDate = value.airDate
        ..airWeekday = value.airWeekday
        ..alias = value.alias
        ..ratingScore = value.ratingScore
        ..votes = value.votes
        ..votesCount = value.votesCount
        ..info = value.info
        ..interest = previousInterest?.hasUserProfile == true
            ? value.interest?.copyWithUser(user: previousInterest!.user)
            : value.interest;
      _infoStatus = InfoLoadStatus.loaded;
      await collectController.updateLocalCollect(_bangumiItem);
    } catch (error) {
      if (request.isStale) return;
      _infoStatus = InfoLoadStatus.failed;
      KazumiLogger().e('Info: failed to load details', error: error);
    }
  }

  @action
  Future<void> loadComments({bool loadMore = false}) =>
      _loadComments(loadMore: loadMore);

  @action
  Future<void> _loadComments(
      {bool loadMore = false, bool silent = false}) async {
    if (_lifetime.isClosed ||
        (_commentsStatus == InfoLoadStatus.loading && !silent)) {
      return;
    }
    final request = _commentRequests.begin();
    _commentsStatus = InfoLoadStatus.loading;
    try {
      final value = await BangumiApi.getBangumiCommentsByID(_bangumiItem.id,
          offset: loadMore ? _commentsOffset : 0);
      if (request.isStale) return;
      _commentsOffset =
          (loadMore ? _commentsOffset : 0) + value.commentList.length;
      _commentsList = List.unmodifiable([
        if (loadMore) ..._commentsList,
        ...value.commentList,
      ]);
      _removeCurrentUserFromPublicComments();
      _commentsStatus = InfoLoadStatus.loaded;
    } catch (error) {
      if (request.isStale) return;
      _commentsStatus = InfoLoadStatus.failed;
      KazumiLogger().e('Info: failed to load comments', error: error);
    }
  }

  @action
  Future<void> loadCharacters() async {
    if (_lifetime.isClosed || _charactersStatus == InfoLoadStatus.loading) {
      return;
    }
    final request = _characterRequests.begin();
    _charactersStatus = InfoLoadStatus.loading;
    try {
      final value = await BangumiApi.getCharatersByBangumiID(_bangumiItem.id);
      if (request.isStale) return;
      const order = {'主角': 1, '配角': 2, '客串': 3};
      final characters = value.charactersList.toList()
        ..sort((a, b) =>
            (order[a.relation] ?? 4).compareTo(order[b.relation] ?? 4));
      _characterList = List.unmodifiable(characters);
      _charactersStatus = InfoLoadStatus.loaded;
    } catch (error) {
      if (request.isStale) return;
      _charactersStatus = InfoLoadStatus.failed;
      KazumiLogger().e('Info: failed to load characters', error: error);
    }
  }

  @action
  Future<void> loadStaff() async {
    if (_lifetime.isClosed || _staffStatus == InfoLoadStatus.loading) return;
    final request = _staffRequests.begin();
    _staffStatus = InfoLoadStatus.loading;
    try {
      final value = await BangumiApi.getBangumiStaffByID(_bangumiItem.id);
      if (request.isStale) return;
      _staffList = List.unmodifiable(value.data);
      _staffStatus = InfoLoadStatus.loaded;
    } catch (error) {
      if (request.isStale) return;
      _staffStatus = InfoLoadStatus.failed;
      KazumiLogger().e('Info: failed to load staff', error: error);
    }
  }

  @action
  Future<void> loadRelations() async {
    if (_lifetime.isClosed || _relationsStatus == InfoLoadStatus.loading) {
      return;
    }
    final request = _relationRequests.begin();
    _relationsStatus = InfoLoadStatus.loading;
    try {
      final relations = await resolveRelatedAnimeChain(
        currentSubjectId: _bangumiItem.id,
        fetchRelations: BangumiApi.getBangumiRelationsByID,
      );
      if (request.isStale) return;
      _relationList = List.unmodifiable(relations);
      _relationsStatus = InfoLoadStatus.loaded;
    } catch (error) {
      if (request.isStale) return;
      _relationsStatus = InfoLoadStatus.failed;
      KazumiLogger().e('Info: failed to load relations', error: error);
    }
  }

  @action
  Future<void> fillInterestUserProfileIfNeeded() async {
    if (_lifetime.isClosed ||
        _isFillingInterestUserProfile ||
        _bangumiItem.interest == null ||
        _bangumiItem.interest!.hasUserProfile) {
      return;
    }
    final subject = _subject;
    _isFillingInterestUserProfile = true;
    try {
      final user = await BangumiApi.getCurrentUser();
      if (subject.isStale || user == null) return;
      _bangumiItem = _bangumiItem.copy()
        ..interest = _bangumiItem.interest?.copyWithUser(user: user);
      _removeCurrentUserFromPublicComments();
      await collectController.updateLocalCollect(_bangumiItem);
    } catch (error) {
      KazumiLogger()
          .e('Info: failed to fill interest user profile', error: error);
    } finally {
      if (subject.isActive) _isFillingInterestUserProfile = false;
    }
  }

  void _removeCurrentUserFromPublicComments() {
    final userId = _bangumiItem.interest?.user?.id;
    if (userId == null) return;
    _commentsList = List.unmodifiable(
        _commentsList.where((item) => item.user.id != userId));
  }

  @action
  Future<bool> rateBangumi(BangumiReview review) async {
    if (_lifetime.isClosed) return false;
    final subject = _subject;
    final id = _bangumiItem.id;
    final updated = await collectController.submitReview(id, review,
        isCurrent: () => subject.isActive);
    if (subject.isStale || !updated) return false;
    _infoRequests.cancel();
    _infoStatus = InfoLoadStatus.idle;
    _bangumiItem = _bangumiItem.copy()
      ..interest = BangumiInterest.mergeLocalSubmission(
        previous: _bangumiItem.interest,
        rate: review.score,
        comment: review.comment,
        tags: review.tags,
      );
    await collectController.updateLocalCollect(_bangumiItem);
    if (subject.isStale) return true;
    await fillInterestUserProfileIfNeeded();
    if (subject.isStale) return true;
    _removeCurrentUserFromPublicComments();
    if (_commentsList.isNotEmpty) await _loadComments(silent: true);
    if (subject.isActive) await loadInfo();
    return true;
  }
}
