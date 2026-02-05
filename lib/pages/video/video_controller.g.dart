// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$VideoPageController on _VideoPageController, Store {
  late final _$episodeCommentsListAtom =
      Atom(name: '_VideoPageController.episodeCommentsList', context: context);

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

  late final _$loadingAtom =
      Atom(name: '_VideoPageController.loading', context: context);

  @override
  bool get loading {
    _$loadingAtom.reportRead();
    return super.loading;
  }

  @override
  set loading(bool value) {
    _$loadingAtom.reportWrite(value, super.loading, () {
      super.loading = value;
    });
  }

  late final _$currentEpisodeAtom =
      Atom(name: '_VideoPageController.currentEpisode', context: context);

  @override
  int get currentEpisode {
    _$currentEpisodeAtom.reportRead();
    return super.currentEpisode;
  }

  @override
  set currentEpisode(int value) {
    _$currentEpisodeAtom.reportWrite(value, super.currentEpisode, () {
      super.currentEpisode = value;
    });
  }

  late final _$currentRoadAtom =
      Atom(name: '_VideoPageController.currentRoad', context: context);

  @override
  int get currentRoad {
    _$currentRoadAtom.reportRead();
    return super.currentRoad;
  }

  @override
  set currentRoad(int value) {
    _$currentRoadAtom.reportWrite(value, super.currentRoad, () {
      super.currentRoad = value;
    });
  }

  late final _$isFullscreenAtom =
      Atom(name: '_VideoPageController.isFullscreen', context: context);

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

  late final _$isCommentsAscendingAtom =
      Atom(name: '_VideoPageController.isCommentsAscending', context: context);

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
      Atom(name: '_VideoPageController.isPip', context: context);

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
      Atom(name: '_VideoPageController.showTabBody', context: context);

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
      Atom(name: '_VideoPageController.historyOffset', context: context);

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
      Atom(name: '_VideoPageController.isOfflineMode', context: context);

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
      Atom(name: '_VideoPageController.roadList', context: context);

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

  @override
  String toString() {
    return '''
episodeCommentsList: ${episodeCommentsList},
loading: ${loading},
currentEpisode: ${currentEpisode},
currentRoad: ${currentRoad},
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
