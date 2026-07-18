// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$VideoPageController on VideoPageControllerBase, Store {
  late final _$episodeCommentsListAtom = Atom(
      name: 'VideoPageControllerBase.episodeCommentsList', context: context);

  @override
  ObservableList<EpisodeCommentItem> get episodeCommentsList {
    _$episodeCommentsListAtom.reportRead();
    return super.episodeCommentsList;
  }

  @override
  set episodeCommentsList(ObservableList<EpisodeCommentItem> value) {
    _$episodeCommentsListAtom.reportWrite(value, super.episodeCommentsList, () {
      super.episodeCommentsList = value;
    });
  }

  late final _$_loadingAtom =
      Atom(name: 'VideoPageControllerBase._loading', context: context);

  bool get loading {
    _$_loadingAtom.reportRead();
    return super._loading;
  }

  @override
  bool get _loading => loading;

  @override
  set _loading(bool value) {
    _$_loadingAtom.reportWrite(value, super._loading, () {
      super._loading = value;
    });
  }

  late final _$_errorMessageAtom =
      Atom(name: 'VideoPageControllerBase._errorMessage', context: context);

  String? get errorMessage {
    _$_errorMessageAtom.reportRead();
    return super._errorMessage;
  }

  @override
  String? get _errorMessage => errorMessage;

  @override
  set _errorMessage(String? value) {
    _$_errorMessageAtom.reportWrite(value, super._errorMessage, () {
      super._errorMessage = value;
    });
  }

  late final _$selectedEpisodeAtom =
      Atom(name: 'VideoPageControllerBase.selectedEpisode', context: context);

  @override
  VideoEpisodeSelection get selectedEpisode {
    _$selectedEpisodeAtom.reportRead();
    return super.selectedEpisode;
  }

  @override
  set selectedEpisode(VideoEpisodeSelection value) {
    _$selectedEpisodeAtom.reportWrite(value, super.selectedEpisode, () {
      super.selectedEpisode = value;
    });
  }

  late final _$playingEpisodeAtom =
      Atom(name: 'VideoPageControllerBase.playingEpisode', context: context);

  @override
  VideoEpisodeSelection? get playingEpisode {
    _$playingEpisodeAtom.reportRead();
    return super.playingEpisode;
  }

  @override
  set playingEpisode(VideoEpisodeSelection? value) {
    _$playingEpisodeAtom.reportWrite(value, super.playingEpisode, () {
      super.playingEpisode = value;
    });
  }

  late final _$commentsEpisodeAtom =
      Atom(name: 'VideoPageControllerBase.commentsEpisode', context: context);

  @override
  int get commentsEpisode {
    _$commentsEpisodeAtom.reportRead();
    return super.commentsEpisode;
  }

  @override
  set commentsEpisode(int value) {
    _$commentsEpisodeAtom.reportWrite(value, super.commentsEpisode, () {
      super.commentsEpisode = value;
    });
  }

  late final _$isFullscreenAtom =
      Atom(name: 'VideoPageControllerBase.isFullscreen', context: context);

  @override
  bool get isFullscreen {
    _$isFullscreenAtom.reportRead();
    return super.isFullscreen;
  }

  @override
  set isFullscreen(bool value) {
    _$isFullscreenAtom.reportWrite(value, super.isFullscreen, () {
      super.isFullscreen = value;
    });
  }

  late final _$isCommentsAscendingAtom = Atom(
      name: 'VideoPageControllerBase.isCommentsAscending', context: context);

  @override
  bool get isCommentsAscending {
    _$isCommentsAscendingAtom.reportRead();
    return super.isCommentsAscending;
  }

  @override
  set isCommentsAscending(bool value) {
    _$isCommentsAscendingAtom.reportWrite(value, super.isCommentsAscending, () {
      super.isCommentsAscending = value;
    });
  }

  late final _$isPipAtom =
      Atom(name: 'VideoPageControllerBase.isPip', context: context);

  @override
  bool get isPip {
    _$isPipAtom.reportRead();
    return super.isPip;
  }

  @override
  set isPip(bool value) {
    _$isPipAtom.reportWrite(value, super.isPip, () {
      super.isPip = value;
    });
  }

  late final _$showTabBodyAtom =
      Atom(name: 'VideoPageControllerBase.showTabBody', context: context);

  @override
  bool get showTabBody {
    _$showTabBodyAtom.reportRead();
    return super.showTabBody;
  }

  @override
  set showTabBody(bool value) {
    _$showTabBodyAtom.reportWrite(value, super.showTabBody, () {
      super.showTabBody = value;
    });
  }

  late final _$historyOffsetAtom =
      Atom(name: 'VideoPageControllerBase.historyOffset', context: context);

  @override
  int get historyOffset {
    _$historyOffsetAtom.reportRead();
    return super.historyOffset;
  }

  @override
  set historyOffset(int value) {
    _$historyOffsetAtom.reportWrite(value, super.historyOffset, () {
      super.historyOffset = value;
    });
  }

  late final _$isOfflineModeAtom =
      Atom(name: 'VideoPageControllerBase.isOfflineMode', context: context);

  @override
  bool get isOfflineMode {
    _$isOfflineModeAtom.reportRead();
    return super.isOfflineMode;
  }

  @override
  set isOfflineMode(bool value) {
    _$isOfflineModeAtom.reportWrite(value, super.isOfflineMode, () {
      super.isOfflineMode = value;
    });
  }

  late final _$roadListAtom =
      Atom(name: 'VideoPageControllerBase.roadList', context: context);

  @override
  ObservableList<Road> get roadList {
    _$roadListAtom.reportRead();
    return super.roadList;
  }

  @override
  set roadList(ObservableList<Road> value) {
    _$roadListAtom.reportWrite(value, super.roadList, () {
      super.roadList = value;
    });
  }

  late final _$VideoPageControllerBaseActionController =
      ActionController(name: 'VideoPageControllerBase', context: context);

  @override
  void resetEpisodeState({int episode = 1, int road = 0}) {
    final _$actionInfo = _$VideoPageControllerBaseActionController.startAction(
        name: 'VideoPageControllerBase.resetEpisodeState');
    try {
      return super.resetEpisodeState(episode: episode, road: road);
    } finally {
      _$VideoPageControllerBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void applyPlaybackArgs(VideoPlaybackArgs args) {
    final _$actionInfo = _$VideoPageControllerBaseActionController.startAction(
        name: 'VideoPageControllerBase.applyPlaybackArgs');
    try {
      return super.applyPlaybackArgs(args);
    } finally {
      _$VideoPageControllerBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _initForOfflinePlayback(
      {required BangumiItem bangumiItem,
      required String pluginName,
      required int episodeNumber,
      required int road,
      required List<DownloadEpisode> downloadedEpisodes}) {
    final _$actionInfo = _$VideoPageControllerBaseActionController.startAction(
        name: 'VideoPageControllerBase._initForOfflinePlayback');
    try {
      return super._initForOfflinePlayback(
          bangumiItem: bangumiItem,
          pluginName: pluginName,
          episodeNumber: episodeNumber,
          road: road,
          downloadedEpisodes: downloadedEpisodes);
    } finally {
      _$VideoPageControllerBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _beginEpisodeSwitch(VideoEpisodeSelection selection) {
    final _$actionInfo = _$VideoPageControllerBaseActionController.startAction(
        name: 'VideoPageControllerBase._beginEpisodeSwitch');
    try {
      return super._beginEpisodeSwitch(selection);
    } finally {
      _$VideoPageControllerBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _applyResolvedSelection(EpisodeRef resolvedEpisode) {
    final _$actionInfo = _$VideoPageControllerBaseActionController.startAction(
        name: 'VideoPageControllerBase._applyResolvedSelection');
    try {
      return super._applyResolvedSelection(resolvedEpisode);
    } finally {
      _$VideoPageControllerBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _finishLoading() {
    final _$actionInfo = _$VideoPageControllerBaseActionController.startAction(
        name: 'VideoPageControllerBase._finishLoading');
    try {
      return super._finishLoading();
    } finally {
      _$VideoPageControllerBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _failLoading(String message) {
    final _$actionInfo = _$VideoPageControllerBaseActionController.startAction(
        name: 'VideoPageControllerBase._failLoading');
    try {
      return super._failLoading(message);
    } finally {
      _$VideoPageControllerBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _applyEpisodeComments(
      int episode, EpisodeInfo info, List<EpisodeCommentItem> comments) {
    final _$actionInfo = _$VideoPageControllerBaseActionController.startAction(
        name: 'VideoPageControllerBase._applyEpisodeComments');
    try {
      return super._applyEpisodeComments(episode, info, comments);
    } finally {
      _$VideoPageControllerBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleSortOrder() {
    final _$actionInfo = _$VideoPageControllerBaseActionController.startAction(
        name: 'VideoPageControllerBase.toggleSortOrder');
    try {
      return super.toggleSortOrder();
    } finally {
      _$VideoPageControllerBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
episodeCommentsList: ${episodeCommentsList},
selectedEpisode: ${selectedEpisode},
playingEpisode: ${playingEpisode},
commentsEpisode: ${commentsEpisode},
isFullscreen: ${isFullscreen},
isCommentsAscending: ${isCommentsAscending},
isPip: ${isPip},
showTabBody: ${showTabBody},
historyOffset: ${historyOffset},
isOfflineMode: ${isOfflineMode},
roadList: ${roadList}
    ''';
  }
}
