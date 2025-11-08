import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:mobx/mobx.dart';

part 'popular_controller.g.dart';

class PopularController = _PopularController with _$PopularController;

abstract class _PopularController with Store {
  late final CollectController collectController;
  final ScrollController scrollController = ScrollController();

  _PopularController() {
    collectController = Modular.get<CollectController>();
    _setupCollectiblesReaction();
  }

  late final ReactionDisposer _collectiblesReactionDisposer;

  void _setupCollectiblesReaction() {
    _collectiblesReactionDisposer = reaction(
      (_) => collectController.lastUpdateTime,
      (_) => filterCurrentLists(),
    );
  }

  void dispose() {
    _collectiblesReactionDisposer();
    scrollController.dispose();
  }

  @observable
  String currentTag = '';

  @observable
  ObservableList<BangumiItem> bangumiList = ObservableList.of([]);

  @observable
  ObservableList<BangumiItem> trendList = ObservableList.of([]);

  List<BangumiItem> _rawBangumiList = [];
  List<BangumiItem> _rawTrendList = [];

  double scrollOffset = 0.0;

  @observable
  bool isLoadingMore = false;

  @observable
  bool isTimeOut = false;

  void setCurrentTag(String s) {
    currentTag = s;
  }

  void clearBangumiList() {
    bangumiList.clear();
    _rawBangumiList.clear();
  }

  Future<void> queryBangumiByTrend({String type = 'add'}) async {
    if (type == 'init') {
      trendList.clear();
      _rawTrendList.clear();
    }
    isLoadingMore = true;
    var result =
        await BangumiHTTP.getBangumiTrendsList(offset: trendList.length);
    _rawTrendList.addAll(result);
    final filteredResult = collectController.filterBangumiByType(result, 5);
    trendList.addAll(filteredResult);
    isLoadingMore = false;
    isTimeOut = trendList.isEmpty;
  }

  Future<void> queryBangumiByTag({String type = 'add'}) async {
    if (type == 'init') {
      bangumiList.clear();
      _rawBangumiList.clear();
    }
    isLoadingMore = true;
    int randomNumber = Random().nextInt(8000) + 1;
    var tag = currentTag;
    var result = await BangumiHTTP.getBangumiList(rank: randomNumber, tag: tag);
    _rawBangumiList.addAll(result);
    final filteredResult = collectController.filterBangumiByType(result, 5);
    bangumiList.addAll(filteredResult);
    isLoadingMore = false;
    isTimeOut = bangumiList.isEmpty;
  }

  @action
  void filterCurrentLists() {
    final abandonedNames = collectController.getBangumiNamesByType(5);

    final filteredBangumiList = _rawBangumiList
        .where((item) => !abandonedNames.contains(item.name))
        .toList();
    final filteredTrendList = _rawTrendList
        .where((item) => !abandonedNames.contains(item.name))
        .toList();

    bangumiList.clear();
    bangumiList.addAll(filteredBangumiList);
    trendList.clear();
    trendList.addAll(filteredTrendList);
  }
}
