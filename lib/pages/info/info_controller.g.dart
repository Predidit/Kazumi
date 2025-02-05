// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'info_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$InfoController on _InfoController, Store {
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
  ObservableMap<String, String> get pluginSearchStatus {
    _$pluginSearchStatusAtom.reportRead();
    return super.pluginSearchStatus;
  }

  @override
  set pluginSearchStatus(ObservableMap<String, String> value) {
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

  late final _$episodeCommentsListAtom =
      Atom(name: '_InfoController.episodeCommentsList', context: context);

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

  @override
  String toString() {
    return '''
pluginSearchResponseList: ${pluginSearchResponseList},
pluginSearchStatus: ${pluginSearchStatus},
commentsList: ${commentsList},
episodeCommentsList: ${episodeCommentsList},
characterList: ${characterList}
    ''';
  }
}
