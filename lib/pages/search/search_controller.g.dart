// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$SearchPageController on _SearchPageController, Store {
  late final _$isLoadingAtom =
      Atom(name: '_SearchPageController.isLoading', context: context);

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

  late final _$isTimeOutAtom =
      Atom(name: '_SearchPageController.isTimeOut', context: context);

  @override
  bool get isTimeOut {
    _$isTimeOutAtom.reportRead();
    return super.isTimeOut;
  }

  @override
  set isTimeOut(bool value) {
    _$isTimeOutAtom.reportWrite(value, super.isTimeOut, () {
      super.isTimeOut = value;
    });
  }

  late final _$searchKeywordAtom =
      Atom(name: '_SearchPageController.searchKeyword', context: context);

  @override
  String get searchKeyword {
    _$searchKeywordAtom.reportRead();
    return super.searchKeyword;
  }

  @override
  set searchKeyword(String value) {
    _$searchKeywordAtom.reportWrite(value, super.searchKeyword, () {
      super.searchKeyword = value;
    });
  }

  late final _$bangumiListAtom =
      Atom(name: '_SearchPageController.bangumiList', context: context);

  @override
  ObservableList<BangumiItem> get bangumiList {
    _$bangumiListAtom.reportRead();
    return super.bangumiList;
  }

  @override
  set bangumiList(ObservableList<BangumiItem> value) {
    _$bangumiListAtom.reportWrite(value, super.bangumiList, () {
      super.bangumiList = value;
    });
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
isTimeOut: ${isTimeOut},
searchKeyword: ${searchKeyword},
bangumiList: ${bangumiList}
    ''';
  }
}
