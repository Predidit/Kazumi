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

  late final _$showWatchedBangumisAtom =
      Atom(name: '_SearchPageController.showWatchedBangumis', context: context);

  @override
  bool get notShowWatchedBangumis {
    _$showWatchedBangumisAtom.reportRead();
    return super.notShowWatchedBangumis;
  }

  bool _showWatchedBangumisIsInitialized = false;

  @override
  set notShowWatchedBangumis(bool value) {
    _$showWatchedBangumisAtom.reportWrite(value,
        _showWatchedBangumisIsInitialized ? super.notShowWatchedBangumis : null,
        () {
      super.notShowWatchedBangumis = value;
      _showWatchedBangumisIsInitialized = true;
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

  late final _$searchHistoriesAtom =
      Atom(name: '_SearchPageController.searchHistories', context: context);

  @override
  ObservableList<SearchHistory> get searchHistories {
    _$searchHistoriesAtom.reportRead();
    return super.searchHistories;
  }

  @override
  set searchHistories(ObservableList<SearchHistory> value) {
    _$searchHistoriesAtom.reportWrite(value, super.searchHistories, () {
      super.searchHistories = value;
    });
  }

  late final _$searchBangumiAsyncAction =
      AsyncAction('_SearchPageController.searchBangumi', context: context);

  @override
  Future<void> searchBangumi(String input, {String type = 'add'}) {
    return _$searchBangumiAsyncAction
        .run(() => super.searchBangumi(input, type: type));
  }

  late final _$deleteSearchHistoryAsyncAction = AsyncAction(
      '_SearchPageController.deleteSearchHistory',
      context: context);

  @override
  Future<void> deleteSearchHistory(SearchHistory history) {
    return _$deleteSearchHistoryAsyncAction
        .run(() => super.deleteSearchHistory(history));
  }

  late final _$clearSearchHistoryAsyncAction =
      AsyncAction('_SearchPageController.clearSearchHistory', context: context);

  @override
  Future<void> clearSearchHistory() {
    return _$clearSearchHistoryAsyncAction
        .run(() => super.clearSearchHistory());
  }

  late final _$setShowWatchedBangumisAsyncAction = AsyncAction(
      '_SearchPageController.setShowWatchedBangumis',
      context: context);

  @override
  Future<void> setNotShowWatchedBangumis(bool value) {
    return _$setShowWatchedBangumisAsyncAction
        .run(() => super.setNotShowWatchedBangumis(value));
  }

  late final _$_SearchPageControllerActionController =
      ActionController(name: '_SearchPageController', context: context);

  @override
  void loadSearchHistories() {
    final _$actionInfo = _$_SearchPageControllerActionController.startAction(
        name: '_SearchPageController.loadSearchHistories');
    try {
      return super.loadSearchHistories();
    } finally {
      _$_SearchPageControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  Set<String> loadWatchedBangumiNames() {
    final _$actionInfo = _$_SearchPageControllerActionController.startAction(
        name: '_SearchPageController.loadWatchedBangumiNames');
    try {
      return super.loadWatchedBangumiNames();
    } finally {
      _$_SearchPageControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
isTimeOut: ${isTimeOut},
showWatchedBangumis: ${notShowWatchedBangumis},
bangumiList: ${bangumiList},
searchHistories: ${searchHistories}
    ''';
  }
}
