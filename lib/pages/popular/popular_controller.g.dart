// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'popular_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PopularController on _PopularController, Store {
  late final _$currentTagAtom =
      Atom(name: '_PopularController.currentTag', context: context);

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

  late final _$showRankingAtom =
      Atom(name: '_PopularController.showRanking', context: context);

  @override
  bool get showRanking {
    _$showRankingAtom.reportRead();
    return super.showRanking;
  }

  @override
  set showRanking(bool value) {
    _$showRankingAtom.reportWrite(value, super.showRanking, () {
      super.showRanking = value;
    });
  }

  late final _$rankingPeriodAtom =
      Atom(name: '_PopularController.rankingPeriod', context: context);

  @override
  BangumiRankingPeriod get rankingPeriod {
    _$rankingPeriodAtom.reportRead();
    return super.rankingPeriod;
  }

  @override
  set rankingPeriod(BangumiRankingPeriod value) {
    _$rankingPeriodAtom.reportWrite(value, super.rankingPeriod, () {
      super.rankingPeriod = value;
    });
  }

  late final _$bangumiListAtom =
      Atom(name: '_PopularController.bangumiList', context: context);

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
      Atom(name: '_PopularController.trendList', context: context);

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

  late final _$rankingListAtom =
      Atom(name: '_PopularController.rankingList', context: context);

  @override
  ObservableList<BangumiItem> get rankingList {
    _$rankingListAtom.reportRead();
    return super.rankingList;
  }

  @override
  set rankingList(ObservableList<BangumiItem> value) {
    _$rankingListAtom.reportWrite(value, super.rankingList, () {
      super.rankingList = value;
    });
  }

  late final _$isLoadingMoreAtom =
      Atom(name: '_PopularController.isLoadingMore', context: context);

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
      Atom(name: '_PopularController.isTimeOut', context: context);

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

  @override
  String toString() {
    return '''
currentTag: ${currentTag},
showRanking: ${showRanking},
rankingPeriod: ${rankingPeriod},
bangumiList: ${bangumiList},
trendList: ${trendList},
rankingList: ${rankingList},
isLoadingMore: ${isLoadingMore},
isTimeOut: ${isTimeOut}
    ''';
  }
}
