import 'dart:math';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/services/network/bangumi_acceleration.dart';
import 'package:mobx/mobx.dart';

part 'popular_controller.g.dart';

class PopularController extends _PopularController with _$PopularController {
  PopularController();

  PopularController.withTagLoader(super.tagLoader) : super.withTagLoader();
}

abstract class _PopularController with Store {
  _PopularController() : _tagLoader = null;

  _PopularController.withTagLoader(
    Future<List<BangumiItem>> Function(String tag, int offset) tagLoader,
  ) : _tagLoader = tagLoader;

  final Future<List<BangumiItem>> Function(String tag, int offset)? _tagLoader;
  static const int _trendPageSize = 24;

  int _trendOffset = 0;
  int _tagRequestId = 0;
  bool _trendLoading = false;

  @observable
  String currentTag = '';

  @observable
  ObservableList<BangumiItem> bangumiList = ObservableList.of([]);

  @observable
  ObservableList<BangumiItem> trendList = ObservableList.of([]);

  double scrollOffset = 0.0;

  @observable
  bool isLoadingMore = false;

  @observable
  bool isTimeOut = false;

  bool get _bangumiMirrorEnabled =>
      BangumiAcceleration.current == BangumiAcceleration.mirror;

  void setCurrentTag(String s) {
    _tagRequestId++;
    runInAction(() {
      currentTag = s;
      isLoadingMore = s.isEmpty && _trendLoading;
      isTimeOut = false;
    });
  }

  void clearBangumiList() {
    bangumiList.clear();
  }

  // Async actions commit each segment between awaits as one transaction,
  // batching the completion writes into a single notification.
  @action
  Future<void> queryBangumiByTrend({String type = 'add'}) async {
    if (_trendLoading) return;
    _trendLoading = true;
    if (type == 'init') {
      trendList.clear();
      _trendOffset = 0;
    }
    if (currentTag.isEmpty) {
      isLoadingMore = true;
      isTimeOut = false;
    }
    try {
      final result = _bangumiMirrorEnabled
          ? await BangumiApi.getBangumiMirrorPopularSubjects(
              limit: _trendPageSize,
              offset: _trendOffset,
            )
          : await BangumiApi.getBangumiTrendsList(
              limit: _trendPageSize,
              offset: _trendOffset,
            );
      if (result.isNotEmpty) {
        _trendOffset += _trendPageSize;
      }
      final existingIds = trendList.map((item) => item.id).toSet();
      trendList.addAll(result.where((item) => existingIds.add(item.id)));
    } finally {
      _trendLoading = false;
      if (currentTag.isEmpty) {
        isLoadingMore = false;
        isTimeOut = trendList.isEmpty;
      }
    }
  }

  @action
  Future<void> queryBangumiByTag({String type = 'add'}) async {
    final requestId = ++_tagRequestId;
    final tag = currentTag;
    if (type == 'init') {
      bangumiList.clear();
    }
    isLoadingMore = true;
    isTimeOut = false;
    try {
      final result = _tagLoader != null
          ? await _tagLoader(tag, bangumiList.length)
          : _bangumiMirrorEnabled
          ? await BangumiApi.getBangumiMirrorPopularSubjects(
              tag: tag,
              offset: bangumiList.length,
            )
          : await BangumiApi.getBangumiList(
              rank: Random().nextInt(8000) + 1,
              tag: tag,
            );
      // A previous category may finish after the user has already switched.
      if (requestId != _tagRequestId || tag != currentTag) return;
      final existingIds = bangumiList.map((item) => item.id).toSet();
      bangumiList.addAll(result.where((item) => existingIds.add(item.id)));
    } finally {
      if (requestId == _tagRequestId && tag == currentTag) {
        isLoadingMore = false;
        isTimeOut = bangumiList.isEmpty;
      }
    }
  }
}
