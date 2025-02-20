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

  void setSearchKeyword(String s) {
    searchKeyword = s;
  }

  void setCurrentTag(String s) {
    currentTag = s;
  }

  Future<bool> queryBangumiFeed({String type = 'add'}) async {
    if (type == 'init') {
      bangumiList.clear();
    }
    isLoadingMore = true;
    var result =
        await BangumiHTTP.getBangumiTrendsList(offset: bangumiList.length);
    bangumiList.addAll(result);
    isLoadingMore = false;
    return true;
  }

  Future<bool> queryBangumiList({String type = 'add'}) async {
    if (type == 'init') {
      bangumiList.clear();
    }
    isLoadingMore = true;
    int randomNumber = Random().nextInt(8000) + 1;
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

  Future<bool> queryBangumiByRefresh() async {
    if (currentTag.isEmpty) {
      return await queryBangumiFeed(type: 'init');
    }
    return await queryBangumiList(type: 'init');
  }

  Future<void> queryBangumi(String keyword) async {
    currentTag = '';
    isLoadingMore = true;
    if (RegExp(r'^[0-9]+$').hasMatch(keyword)) {
      // 纯数字时调用ID查询
      final id = int.parse(keyword);
      final BangumiItem? item = await BangumiHTTP.getBangumiInfoByID(id);
      
      bangumiList.clear();
      if (item != null) {
        bangumiList.add(item); // 单个结果转为列表
      }
    } else {
      // 非数字时调用普通搜索
      var result = await BangumiHTTP.bangumiSearch(keyword);
      bangumiList.clear();
      bangumiList.addAll(result);
    }
    isLoadingMore = false;
  }
}
