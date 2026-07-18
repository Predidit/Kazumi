// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'popular_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PopularController on PopularControllerBase, Store {
  late final _$currentTagAtom =
      Atom(name: 'PopularControllerBase.currentTag', context: context);

  @override
  String get currentTag {
    _$currentTagAtom.reportRead();
    return super.currentTag;
  }

  @override
  set currentTag(String value) {
    _$currentTagAtom.reportWrite(value, super.currentTag, () {
      super.currentTag = value;
    });
  }

  late final _$bangumiListAtom =
      Atom(name: 'PopularControllerBase.bangumiList', context: context);

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

  late final _$trendListAtom =
      Atom(name: 'PopularControllerBase.trendList', context: context);

  @override
  ObservableList<BangumiItem> get trendList {
    _$trendListAtom.reportRead();
    return super.trendList;
  }

  @override
  set trendList(ObservableList<BangumiItem> value) {
    _$trendListAtom.reportWrite(value, super.trendList, () {
      super.trendList = value;
    });
  }

  late final _$isLoadingMoreAtom =
      Atom(name: 'PopularControllerBase.isLoadingMore', context: context);

  @override
  bool get isLoadingMore {
    _$isLoadingMoreAtom.reportRead();
    return super.isLoadingMore;
  }

  @override
  set isLoadingMore(bool value) {
    _$isLoadingMoreAtom.reportWrite(value, super.isLoadingMore, () {
      super.isLoadingMore = value;
    });
  }

  late final _$isTimeOutAtom =
      Atom(name: 'PopularControllerBase.isTimeOut', context: context);

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

  late final _$queryBangumiByTrendAsyncAction = AsyncAction(
      'PopularControllerBase.queryBangumiByTrend',
      context: context);

  @override
  Future<void> queryBangumiByTrend({String type = 'add'}) {
    return _$queryBangumiByTrendAsyncAction
        .run(() => super.queryBangumiByTrend(type: type));
  }

  late final _$queryBangumiByTagAsyncAction =
      AsyncAction('PopularControllerBase.queryBangumiByTag', context: context);

  @override
  Future<void> queryBangumiByTag({String type = 'add'}) {
    return _$queryBangumiByTagAsyncAction
        .run(() => super.queryBangumiByTag(type: type));
  }

  @override
  String toString() {
    return '''
currentTag: ${currentTag},
bangumiList: ${bangumiList},
trendList: ${trendList},
isLoadingMore: ${isLoadingMore},
isTimeOut: ${isTimeOut}
    ''';
  }
}
