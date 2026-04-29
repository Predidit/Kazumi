import 'dart:math';
import 'package:flutter/material.dart';
import 'package:kazumi/modules/bangumi/bangumi_ranking_period.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:mobx/mobx.dart';

part 'popular_controller.g.dart';

const String popularRankingModeKey = '__ranking__';

class PopularController = _PopularController with _$PopularController;

abstract class _PopularController with Store {
  final ScrollController scrollController = ScrollController();

  @observable
  String currentTag = '';

  @observable
  bool showRanking = false;

  @observable
  BangumiRankingPeriod rankingPeriod = BangumiRankingPeriod.month;

  @observable
  ObservableList<BangumiItem> bangumiList = ObservableList.of([]);

  @observable
  ObservableList<BangumiItem> trendList = ObservableList.of([]);

  @observable
  ObservableList<BangumiItem> rankingList = ObservableList.of([]);

  double scrollOffset = 0.0;

  @observable
  bool isLoadingMore = false;

  @observable
  bool isTimeOut = false;

  void setCurrentTag(String s) {
    currentTag = s;
    showRanking = false;
    isTimeOut = false;
  }

  void enterRankingMode() {
    currentTag = '';
    showRanking = true;
    isTimeOut = false;
  }

  Future<void> setRankingPeriod(BangumiRankingPeriod period) async {
    if (rankingPeriod == period) {
      return;
    }
    rankingPeriod = period;
    rankingList.clear();
    await queryBangumiByRanking(type: 'init');
  }

  void clearBangumiList() {
    bangumiList.clear();
  }

  Future<void> queryBangumiByTrend({String type = 'add'}) async {
    if (type == 'init') {
      trendList.clear();
    }
    isTimeOut = false;
    isLoadingMore = true;
    var result =
        await BangumiHTTP.getBangumiTrendsList(offset: trendList.length);
    trendList.addAll(result);
    isLoadingMore = false;
    isTimeOut = trendList.isEmpty;
  }

  Future<void> queryBangumiByRanking({String type = 'add'}) async {
    if (type == 'init') {
      rankingList.clear();
    }
    isTimeOut = false;
    isLoadingMore = true;
    var result = await BangumiHTTP.getBangumiRankingList(
      period: rankingPeriod,
      offset: rankingList.length,
    );
    rankingList.addAll(result);
    isLoadingMore = false;
    isTimeOut = rankingList.isEmpty;
  }

  Future<void> queryBangumiByTag({String type = 'add'}) async {
    if (type == 'init') {
      bangumiList.clear();
    }
    isTimeOut = false;
    isLoadingMore = true;
    int randomNumber = Random().nextInt(8000) + 1;
    var tag = currentTag;
    var result = await BangumiHTTP.getBangumiList(rank: randomNumber, tag: tag);
    bangumiList.addAll(result);
    isLoadingMore = false;
    isTimeOut = bangumiList.isEmpty;
  }
}
