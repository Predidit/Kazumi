import 'package:flutter/material.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/modules/bangumi/calendar_module.dart';
import 'package:mobx/mobx.dart';

part 'popular_controller.g.dart';

class PopularController = _PopularController with _$PopularController;

abstract class _PopularController with Store {
  final ScrollController scrollController = ScrollController();

  @observable
  ObservableList<BangumiItem> bangumiList = ObservableList.of([BangumiItem()]);

  double scrollOffset = 0.0;
  bool isLoadingMore = true;

  Future queryBangumiListFeed() async { 
    var result = await BangumiHTTP.getBangumiList();
    bangumiList.clear();
    bangumiList.addAll(result);
    isLoadingMore = false;
  }
}