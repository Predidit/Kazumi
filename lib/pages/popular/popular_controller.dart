import 'dart:math';
import 'package:flutter/material.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:mobx/mobx.dart';

part 'popular_controller.g.dart';

class PopularController = _PopularController with _$PopularController;

abstract class _PopularController with Store {
  final ScrollController scrollController = ScrollController();

  String keyword = '';
  String searchKeyword = '';
  bool isSearching = false;

  @observable
  String currentTag = '';

  @observable
  ObservableList<BangumiItem> bangumiList = ObservableList.of([]);

  double scrollOffset = 0.0;

  @observable
  bool isLoadingMore = false;

  @observable
  bool isTimeOut = false;

  void setSearchKeyword(String s) {
    isSearching = s.isNotEmpty;
    searchKeyword = s;
  }

  Future<bool> queryLatestBangumiUpdates() async {
    var result = await BangumiHTTP.getCalendar();
    List<BangumiItem> bangumiList = [];
    var today = DateTime.now().weekday;
    List<List<int>> weekdayOrder = [
      [1, 7, 6],
      [2, 1, 7],
      [3, 2, 1],
      [4, 3, 2],
      [5, 4, 3],
      [6, 5, 4],
      [7, 6, 5],
    ];
    for (int day in weekdayOrder[today - 1]) {
      bangumiList.addAll(result[day - 1]);
    }
    // [X|未实现]只保留tags中含有 "tag": ["日本"] 的番剧，效率很低
    this.bangumiList = ObservableList.of(bangumiList);
    return true;
  }

  Future<bool> queryBangumiListFeed() async {
    isLoadingMore = true;
    int randomNumber = Random().nextInt(1000) + 1;
    var tag = currentTag;
    var result = await BangumiHTTP.getBangumiList(rank: randomNumber, tag: tag);
    if (currentTag == tag) {
      bangumiList.addAll(result);
      isLoadingMore = false;
      isTimeOut = bangumiList.isEmpty;
      return true;
    }
    return false;
  }

  Future<bool> queryBangumiListFeedByTag(String tag) async {
    currentTag = tag;
    isLoadingMore = true;
    int randomNumber = Random().nextInt(1000) + 1;
    var result = await BangumiHTTP.getBangumiList(rank: randomNumber, tag: tag);
    if (currentTag == tag) {
      bangumiList.clear();
      bangumiList.addAll(result);
      isLoadingMore = false;
      isTimeOut = bangumiList.isEmpty;
      return true;
    }
    return false;
  }

  Future<bool> queryBangumiListFeedByRefresh() async{
    return await queryBangumiListFeedByTag(currentTag);
  }

  Future<void> queryBangumi(String keyword) async {
    currentTag = '';
    isLoadingMore = true;
    var result = await BangumiHTTP.bangumiSearch(keyword);
    bangumiList.clear();
    bangumiList.addAll(result);
    isLoadingMore = false;
  }
}
