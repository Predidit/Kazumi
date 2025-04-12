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

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
pluginSearchResponseList: ${pluginSearchResponseList},
pluginSearchStatus: ${pluginSearchStatus},
commentsList: ${commentsList},
characterList: ${characterList},
staffList: ${staffList}
    ''';
  }
}
