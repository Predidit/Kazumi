// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'info_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$InfoController on _InfoController, Store {
  late final _$_bangumiItemAtom =
      Atom(name: '_InfoController._bangumiItem', context: context);

  BangumiItem get bangumiItem {
    _$_bangumiItemAtom.reportRead();
    return super._bangumiItem;
  }

  @override
  BangumiItem get _bangumiItem => bangumiItem;

  bool __bangumiItemIsInitialized = false;

  @override
  set _bangumiItem(BangumiItem value) {
    _$_bangumiItemAtom.reportWrite(
        value, __bangumiItemIsInitialized ? super._bangumiItem : null, () {
      super._bangumiItem = value;
      __bangumiItemIsInitialized = true;
    });
  }

  late final _$_infoStatusAtom =
      Atom(name: '_InfoController._infoStatus', context: context);

  InfoLoadStatus get infoStatus {
    _$_infoStatusAtom.reportRead();
    return super._infoStatus;
  }

  @override
  InfoLoadStatus get _infoStatus => infoStatus;

  @override
  set _infoStatus(InfoLoadStatus value) {
    _$_infoStatusAtom.reportWrite(value, super._infoStatus, () {
      super._infoStatus = value;
    });
  }

  late final _$_commentsStatusAtom =
      Atom(name: '_InfoController._commentsStatus', context: context);

  InfoLoadStatus get commentsStatus {
    _$_commentsStatusAtom.reportRead();
    return super._commentsStatus;
  }

  @override
  InfoLoadStatus get _commentsStatus => commentsStatus;

  @override
  set _commentsStatus(InfoLoadStatus value) {
    _$_commentsStatusAtom.reportWrite(value, super._commentsStatus, () {
      super._commentsStatus = value;
    });
  }

  late final _$_charactersStatusAtom =
      Atom(name: '_InfoController._charactersStatus', context: context);

  InfoLoadStatus get charactersStatus {
    _$_charactersStatusAtom.reportRead();
    return super._charactersStatus;
  }

  @override
  InfoLoadStatus get _charactersStatus => charactersStatus;

  @override
  set _charactersStatus(InfoLoadStatus value) {
    _$_charactersStatusAtom.reportWrite(value, super._charactersStatus, () {
      super._charactersStatus = value;
    });
  }

  late final _$_staffStatusAtom =
      Atom(name: '_InfoController._staffStatus', context: context);

  InfoLoadStatus get staffStatus {
    _$_staffStatusAtom.reportRead();
    return super._staffStatus;
  }

  @override
  InfoLoadStatus get _staffStatus => staffStatus;

  @override
  set _staffStatus(InfoLoadStatus value) {
    _$_staffStatusAtom.reportWrite(value, super._staffStatus, () {
      super._staffStatus = value;
    });
  }

  late final _$_relationsStatusAtom =
      Atom(name: '_InfoController._relationsStatus', context: context);

  InfoLoadStatus get relationsStatus {
    _$_relationsStatusAtom.reportRead();
    return super._relationsStatus;
  }

  @override
  InfoLoadStatus get _relationsStatus => relationsStatus;

  @override
  set _relationsStatus(InfoLoadStatus value) {
    _$_relationsStatusAtom.reportWrite(value, super._relationsStatus, () {
      super._relationsStatus = value;
    });
  }

  late final _$_commentsListAtom =
      Atom(name: '_InfoController._commentsList', context: context);

  List<CommentItem> get commentsList {
    _$_commentsListAtom.reportRead();
    return super._commentsList;
  }

  @override
  List<CommentItem> get _commentsList => commentsList;

  @override
  set _commentsList(List<CommentItem> value) {
    _$_commentsListAtom.reportWrite(value, super._commentsList, () {
      super._commentsList = value;
    });
  }

  late final _$_characterListAtom =
      Atom(name: '_InfoController._characterList', context: context);

  List<CharacterItem> get characterList {
    _$_characterListAtom.reportRead();
    return super._characterList;
  }

  @override
  List<CharacterItem> get _characterList => characterList;

  @override
  set _characterList(List<CharacterItem> value) {
    _$_characterListAtom.reportWrite(value, super._characterList, () {
      super._characterList = value;
    });
  }

  late final _$_staffListAtom =
      Atom(name: '_InfoController._staffList', context: context);

  List<StaffFullItem> get staffList {
    _$_staffListAtom.reportRead();
    return super._staffList;
  }

  @override
  List<StaffFullItem> get _staffList => staffList;

  @override
  set _staffList(List<StaffFullItem> value) {
    _$_staffListAtom.reportWrite(value, super._staffList, () {
      super._staffList = value;
    });
  }

  late final _$_relationListAtom =
      Atom(name: '_InfoController._relationList', context: context);

  List<BangumiRelation> get relationList {
    _$_relationListAtom.reportRead();
    return super._relationList;
  }

  @override
  List<BangumiRelation> get _relationList => relationList;

  @override
  set _relationList(List<BangumiRelation> value) {
    _$_relationListAtom.reportWrite(value, super._relationList, () {
      super._relationList = value;
    });
  }

  late final _$pluginSearchResponseListAtom =
      Atom(name: '_InfoController.pluginSearchResponseList', context: context);

  @override
  ObservableList<PluginSearchResponse> get pluginSearchResponseList {
    _$pluginSearchResponseListAtom.reportRead();
    return super.pluginSearchResponseList;
  }

  @override
  set pluginSearchResponseList(ObservableList<PluginSearchResponse> value) {
    _$pluginSearchResponseListAtom
        .reportWrite(value, super.pluginSearchResponseList, () {
      super.pluginSearchResponseList = value;
    });
  }

  late final _$pluginSearchStatusAtom =
      Atom(name: '_InfoController.pluginSearchStatus', context: context);

  @override
  ObservableMap<String, PluginSearchStatus> get pluginSearchStatus {
    _$pluginSearchStatusAtom.reportRead();
    return super.pluginSearchStatus;
  }

  @override
  set pluginSearchStatus(ObservableMap<String, PluginSearchStatus> value) {
    _$pluginSearchStatusAtom.reportWrite(value, super.pluginSearchStatus, () {
      super.pluginSearchStatus = value;
    });
  }

  late final _$loadInfoAsyncAction =
      AsyncAction('_InfoController.loadInfo', context: context);

  @override
  Future<void> loadInfo() {
    return _$loadInfoAsyncAction.run(() => super.loadInfo());
  }

  late final _$_loadCommentsAsyncAction =
      AsyncAction('_InfoController._loadComments', context: context);

  @override
  Future<void> _loadComments({bool loadMore = false, bool silent = false}) {
    return _$_loadCommentsAsyncAction
        .run(() => super._loadComments(loadMore: loadMore, silent: silent));
  }

  late final _$loadCharactersAsyncAction =
      AsyncAction('_InfoController.loadCharacters', context: context);

  @override
  Future<void> loadCharacters() {
    return _$loadCharactersAsyncAction.run(() => super.loadCharacters());
  }

  late final _$loadStaffAsyncAction =
      AsyncAction('_InfoController.loadStaff', context: context);

  @override
  Future<void> loadStaff() {
    return _$loadStaffAsyncAction.run(() => super.loadStaff());
  }

  late final _$loadRelationsAsyncAction =
      AsyncAction('_InfoController.loadRelations', context: context);

  @override
  Future<void> loadRelations() {
    return _$loadRelationsAsyncAction.run(() => super.loadRelations());
  }

  late final _$fillInterestUserProfileIfNeededAsyncAction = AsyncAction(
      '_InfoController.fillInterestUserProfileIfNeeded',
      context: context);

  @override
  Future<void> fillInterestUserProfileIfNeeded() {
    return _$fillInterestUserProfileIfNeededAsyncAction
        .run(() => super.fillInterestUserProfileIfNeeded());
  }

  late final _$rateBangumiAsyncAction =
      AsyncAction('_InfoController.rateBangumi', context: context);

  @override
  Future<bool> rateBangumi(BangumiReview review) {
    return _$rateBangumiAsyncAction.run(() => super.rateBangumi(review));
  }

  late final _$_InfoControllerActionController =
      ActionController(name: '_InfoController', context: context);

  @override
  void initialize(BangumiItem item) {
    final _$actionInfo = _$_InfoControllerActionController.startAction(
        name: '_InfoController.initialize');
    try {
      return super.initialize(item);
    } finally {
      _$_InfoControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  Future<void> loadComments({bool loadMore = false}) {
    final _$actionInfo = _$_InfoControllerActionController.startAction(
        name: '_InfoController.loadComments');
    try {
      return super.loadComments(loadMore: loadMore);
    } finally {
      _$_InfoControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
pluginSearchResponseList: ${pluginSearchResponseList},
pluginSearchStatus: ${pluginSearchStatus}
    ''';
  }
}
