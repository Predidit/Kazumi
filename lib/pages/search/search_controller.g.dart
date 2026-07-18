// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$SearchPageController on SearchPageControllerBase, Store {
  late final _$isLoadingAtom =
      Atom(name: 'SearchPageControllerBase.isLoading', context: context);

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
      Atom(name: 'SearchPageControllerBase.isTimeOut', context: context);

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

  late final _$notShowWatchedBangumisAtom = Atom(
      name: 'SearchPageControllerBase.notShowWatchedBangumis',
      context: context);

  @override
  bool get notShowWatchedBangumis {
    _$notShowWatchedBangumisAtom.reportRead();
    return super.notShowWatchedBangumis;
  }

  @override
  set notShowWatchedBangumis(bool value) {
    _$notShowWatchedBangumisAtom
        .reportWrite(value, super.notShowWatchedBangumis, () {
      super.notShowWatchedBangumis = value;
    });
  }

  late final _$notShowAbandonedBangumisAtom = Atom(
      name: 'SearchPageControllerBase.notShowAbandonedBangumis',
      context: context);

  @override
  bool get notShowAbandonedBangumis {
    _$notShowAbandonedBangumisAtom.reportRead();
    return super.notShowAbandonedBangumis;
  }

  @override
  set notShowAbandonedBangumis(bool value) {
    _$notShowAbandonedBangumisAtom
        .reportWrite(value, super.notShowAbandonedBangumis, () {
      super.notShowAbandonedBangumis = value;
    });
  }

  late final _$bangumiListAtom =
      Atom(name: 'SearchPageControllerBase.bangumiList', context: context);

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
      Atom(name: 'SearchPageControllerBase.searchHistories', context: context);

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

  late final _$isImageSearchingAtom =
      Atom(name: 'SearchPageControllerBase.isImageSearching', context: context);

  @override
  bool get isImageSearching {
    _$isImageSearchingAtom.reportRead();
    return super.isImageSearching;
  }

  @override
  set isImageSearching(bool value) {
    _$isImageSearchingAtom.reportWrite(value, super.isImageSearching, () {
      super.isImageSearching = value;
    });
  }

  late final _$imageSearchErrorAtom =
      Atom(name: 'SearchPageControllerBase.imageSearchError', context: context);

  @override
  String get imageSearchError {
    _$imageSearchErrorAtom.reportRead();
    return super.imageSearchError;
  }

  @override
  set imageSearchError(String value) {
    _$imageSearchErrorAtom.reportWrite(value, super.imageSearchError, () {
      super.imageSearchError = value;
    });
  }

  late final _$imageSearchResultsAtom = Atom(
      name: 'SearchPageControllerBase.imageSearchResults', context: context);

  @override
  ObservableList<ResultItem> get imageSearchResults {
    _$imageSearchResultsAtom.reportRead();
    return super.imageSearchResults;
  }

  @override
  set imageSearchResults(ObservableList<ResultItem> value) {
    _$imageSearchResultsAtom.reportWrite(value, super.imageSearchResults, () {
      super.imageSearchResults = value;
    });
  }

  late final _$searchBangumiAsyncAction =
      AsyncAction('SearchPageControllerBase.searchBangumi', context: context);

  @override
  Future<void> searchBangumi(String input, {String type = 'add'}) {
    return _$searchBangumiAsyncAction
        .run(() => super.searchBangumi(input, type: type));
  }

  late final _$deleteSearchHistoryAsyncAction = AsyncAction(
      'SearchPageControllerBase.deleteSearchHistory',
      context: context);

  @override
  Future<void> deleteSearchHistory(SearchHistory history) {
    return _$deleteSearchHistoryAsyncAction
        .run(() => super.deleteSearchHistory(history));
  }

  late final _$clearSearchHistoryAsyncAction = AsyncAction(
      'SearchPageControllerBase.clearSearchHistory',
      context: context);

  @override
  Future<void> clearSearchHistory() {
    return _$clearSearchHistoryAsyncAction
        .run(() => super.clearSearchHistory());
  }

  late final _$searchImageByFileAsyncAction = AsyncAction(
      'SearchPageControllerBase.searchImageByFile',
      context: context);

  @override
  Future<void> searchImageByFile(File imageFile) {
    return _$searchImageByFileAsyncAction
        .run(() => super.searchImageByFile(imageFile));
  }

  late final _$searchImageByUrlAsyncAction = AsyncAction(
      'SearchPageControllerBase.searchImageByUrl',
      context: context);

  @override
  Future<void> searchImageByUrl(String imageUrl) {
    return _$searchImageByUrlAsyncAction
        .run(() => super.searchImageByUrl(imageUrl));
  }

  late final _$setNotShowWatchedBangumisAsyncAction = AsyncAction(
      'SearchPageControllerBase.setNotShowWatchedBangumis',
      context: context);

  @override
  Future<void> setNotShowWatchedBangumis(bool value) {
    return _$setNotShowWatchedBangumisAsyncAction
        .run(() => super.setNotShowWatchedBangumis(value));
  }

  late final _$setNotShowAbandonedBangumisAsyncAction = AsyncAction(
      'SearchPageControllerBase.setNotShowAbandonedBangumis',
      context: context);

  @override
  Future<void> setNotShowAbandonedBangumis(bool value) {
    return _$setNotShowAbandonedBangumisAsyncAction
        .run(() => super.setNotShowAbandonedBangumis(value));
  }

  late final _$SearchPageControllerBaseActionController =
      ActionController(name: 'SearchPageControllerBase', context: context);

  @override
  void loadSearchHistories() {
    final _$actionInfo = _$SearchPageControllerBaseActionController.startAction(
        name: 'SearchPageControllerBase.loadSearchHistories');
    try {
      return super.loadSearchHistories();
    } finally {
      _$SearchPageControllerBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearImageSearchState() {
    final _$actionInfo = _$SearchPageControllerBaseActionController.startAction(
        name: 'SearchPageControllerBase.clearImageSearchState');
    try {
      return super.clearImageSearchState();
    } finally {
      _$SearchPageControllerBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
isTimeOut: ${isTimeOut},
notShowWatchedBangumis: ${notShowWatchedBangumis},
notShowAbandonedBangumis: ${notShowAbandonedBangumis},
bangumiList: ${bangumiList},
searchHistories: ${searchHistories},
isImageSearching: ${isImageSearching},
imageSearchError: ${imageSearchError},
imageSearchResults: ${imageSearchResults}
    ''';
  }
}
