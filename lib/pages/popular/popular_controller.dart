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
  String currentTag = '';

  @observable
  ObservableList<BangumiItem> bangumiList = ObservableList.of([]);

  double scrollOffset = 0.0;
  bool isLoadingMore = false;


  Future<bool> queryBangumiListFeed({String type = 'init', String tag = '', bool useCurrTag = false}) async {
    if(!useCurrTag){
      currentTag = tag;
    }
    isLoadingMore = true;
    var random = Random();
    int randomNumber = random.nextInt(1000) + 1;
    var result = await BangumiHTTP.getBangumiList(rank: randomNumber, tag: tag);
    if (currentTag == tag) {
      if (type == 'init') {
        bangumiList.clear();
      }
      bangumiList.addAll(result);
      isLoadingMore = false;
      return true;
    }
    return false;
  }

  Future<void> queryBangumi(String keyword) async {
    isLoadingMore = true;
    var result = await BangumiHTTP.bangumiSearch(keyword);
    bangumiList.clear();
    bangumiList.addAll(result);
    isLoadingMore = false;
  }
}
