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

  @observable
  String currentTag = '';

  @observable
  ObservableList<BangumiItem> bangumiList = ObservableList.of([]);

  double scrollOffset = 0.0;

  @observable
  bool isLoadingMore = false;

  @observable
  bool isTimeOut = false;


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
    isLoadingMore = true;
    var result = await BangumiHTTP.bangumiSearch(keyword);
    bangumiList.clear();
    bangumiList.addAll(result);
    isLoadingMore = false;
  }
}
