// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$SearchPageController on _SearchPageController, Store {
  late final _$hasMoreSearchResultsAtom = Atom(
      name: '_SearchPageController.hasMoreSearchResults', context: context);

  @override
  bool get hasMoreSearchResults {
    _$hasMoreSearchResultsAtom.reportRead();
    return super.hasMoreSearchResults;
  }

  @override
  set hasMoreSearchResults(bool value) {
    _$hasMoreSearchResultsAtom.reportWrite(value, super.hasMoreSearchResults,
        () {
      super.hasMoreSearchResults = value;
    });
  }

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

  late final _$notShowAbandonedBangumisAtom = Atom(
      name: '_SearchPageController.notShowAbandonedBangumis', context: context);

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

  late final _$selectedViewModeAtom =
      Atom(name: '_SearchPageController.selectedViewMode', context: context);

  @override
  SearchViewMode get selectedViewMode {
    _$selectedViewModeAtom.reportRead();
    return super.selectedViewMode;
  }

  @override
  set selectedViewMode(SearchViewMode value) {
    _$selectedViewModeAtom.reportWrite(value, super.selectedViewMode, () {
      super.selectedViewMode = value;
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

  late final _$isImageSearchingAtom =
      Atom(name: '_SearchPageController.isImageSearching', context: context);

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
      Atom(name: '_SearchPageController.imageSearchError', context: context);

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

  late final _$imageSearchResultsAtom =
      Atom(name: '_SearchPageController.imageSearchResults', context: context);

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
      AsyncAction('_SearchPageController.searchBangumi', context: context);

  @override
  Future<void> searchBangumi(String input, {String type = 'add'}) {
    return _$searchBangumiAsyncAction
        .run(() => super.searchBangumi(input, type: type));
  }

  late final _$requestViewModeAsyncAction =
      AsyncAction('_SearchPageController.requestViewMode', context: context);

  @override
  Future<void> requestViewMode(SearchViewMode mode) {
    return _$requestViewModeAsyncAction.run(() => super.requestViewMode(mode));
  }

  late final _$loadMoreSearchResultsAsyncAction = AsyncAction(
      '_SearchPageController.loadMoreSearchResults',
      context: context);

  @override
  Future<void> loadMoreSearchResults() {
    return _$loadMoreSearchResultsAsyncAction
        .run(() => super.loadMoreSearchResults());
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

  late final _$searchImageByFileAsyncAction =
      AsyncAction('_SearchPageController.searchImageByFile', context: context);

  @override
  Future<void> searchImageByFile(File imageFile) {
    return _$searchImageByFileAsyncAction
        .run(() => super.searchImageByFile(imageFile));
  }

  late final _$searchImageByUrlAsyncAction =
      AsyncAction('_SearchPageController.searchImageByUrl', context: context);

  @override
  Future<void> searchImageByUrl(String imageUrl) {
    return _$searchImageByUrlAsyncAction
        .run(() => super.searchImageByUrl(imageUrl));
  }

  late final _$setNotShowAbandonedBangumisAsyncAction = AsyncAction(
      '_SearchPageController.setNotShowAbandonedBangumis',
      context: context);

  @override
  Future<void> setNotShowAbandonedBangumis(bool value) {
    return _$setNotShowAbandonedBangumisAsyncAction
        .run(() => super.setNotShowAbandonedBangumis(value));
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
  void clearImageSearchState() {
    final _$actionInfo = _$_SearchPageControllerActionController.startAction(
        name: '_SearchPageController.clearImageSearchState');
    try {
      return super.clearImageSearchState();
    } finally {
      _$_SearchPageControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  void refreshResultProjection() {
    final _$actionInfo = _$_SearchPageControllerActionController.startAction(
        name: '_SearchPageController.refreshResultProjection');
    try {
      return super.refreshResultProjection();
    } finally {
      _$_SearchPageControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
hasMoreSearchResults: ${hasMoreSearchResults},
isLoading: ${isLoading},
isTimeOut: ${isTimeOut},
notShowAbandonedBangumis: ${notShowAbandonedBangumis},
bangumiList: ${bangumiList},
selectedViewMode: ${selectedViewMode},
searchHistories: ${searchHistories},
isImageSearching: ${isImageSearching},
imageSearchError: ${imageSearchError},
imageSearchResults: ${imageSearchResults}
    ''';
  }
}
