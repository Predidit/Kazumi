// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'info_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$InfoController on _InfoController, Store {
  late final _$isLoadingAtom =
      Atom(name: '_InfoController.isLoading', context: context);

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
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

  late final _$commentsListAtom =
      Atom(name: '_InfoController.commentsList', context: context);

  @override
  ObservableList<CommentItem> get commentsList {
    _$commentsListAtom.reportRead();
    return super.commentsList;
  }

  @override
  set commentsList(ObservableList<CommentItem> value) {
    _$commentsListAtom.reportWrite(value, super.commentsList, () {
      super.commentsList = value;
    });
  }

  late final _$characterListAtom =
      Atom(name: '_InfoController.characterList', context: context);

  @override
  ObservableList<CharacterItem> get characterList {
    _$characterListAtom.reportRead();
    return super.characterList;
  }

  @override
  set characterList(ObservableList<CharacterItem> value) {
    _$characterListAtom.reportWrite(value, super.characterList, () {
      super.characterList = value;
    });
  }

  late final _$staffListAtom =
      Atom(name: '_InfoController.staffList', context: context);

  @override
  ObservableList<StaffFullItem> get staffList {
    _$staffListAtom.reportRead();
    return super.staffList;
  }

  @override
  set staffList(ObservableList<StaffFullItem> value) {
    _$staffListAtom.reportWrite(value, super.staffList, () {
      super.staffList = value;
    });
  }

  late final _$episodeListAtom =
      Atom(name: '_InfoController.episodeList', context: context);

  @override
  ObservableList<EpisodeInfo> get episodeList {
    _$episodeListAtom.reportRead();
    return super.episodeList;
  }

  @override
  set episodeList(ObservableList<EpisodeInfo> value) {
    _$episodeListAtom.reportWrite(value, super.episodeList, () {
      super.episodeList = value;
    });
  }

  late final _$episodesIsLoadingAtom =
      Atom(name: '_InfoController.episodesIsLoading', context: context);

  @override
  bool get episodesIsLoading {
    _$episodesIsLoadingAtom.reportRead();
    return super.episodesIsLoading;
  }

  @override
  set episodesIsLoading(bool value) {
    _$episodesIsLoadingAtom.reportWrite(value, super.episodesIsLoading, () {
      super.episodesIsLoading = value;
    });
  }

  late final _$episodesQueryTimeoutAtom =
      Atom(name: '_InfoController.episodesQueryTimeout', context: context);

  @override
  bool get episodesQueryTimeout {
    _$episodesQueryTimeoutAtom.reportRead();
    return super.episodesQueryTimeout;
  }

  @override
  set episodesQueryTimeout(bool value) {
    _$episodesQueryTimeoutAtom.reportWrite(value, super.episodesQueryTimeout,
        () {
      super.episodesQueryTimeout = value;
    });
  }

  late final _$episodesIsEmptyAtom =
      Atom(name: '_InfoController.episodesIsEmpty', context: context);

  @override
  bool get episodesIsEmpty {
    _$episodesIsEmptyAtom.reportRead();
    return super.episodesIsEmpty;
  }

  @override
  set episodesIsEmpty(bool value) {
    _$episodesIsEmptyAtom.reportWrite(value, super.episodesIsEmpty, () {
      super.episodesIsEmpty = value;
    });
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
pluginSearchResponseList: ${pluginSearchResponseList},
pluginSearchStatus: ${pluginSearchStatus},
commentsList: ${commentsList},
characterList: ${characterList},
staffList: ${staffList},
episodeList: ${episodeList},
episodesIsLoading: ${episodesIsLoading},
episodesQueryTimeout: ${episodesQueryTimeout},
episodesIsEmpty: ${episodesIsEmpty}
    ''';
  }
}
