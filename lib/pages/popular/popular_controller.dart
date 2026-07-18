import 'dart:math';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:mobx/mobx.dart';

part 'popular_controller.g.dart';

typedef PopularTrendLoader = Future<List<BangumiItem>> Function(int offset);
typedef PopularTagLoader = Future<List<BangumiItem>> Function(
  String tag,
  int offset,
);

class PopularController = PopularControllerBase with _$PopularController;

abstract class PopularControllerBase with Store {
  PopularControllerBase({
    PopularTrendLoader? trendLoader,
    PopularTagLoader? tagLoader,
  })  : _trendLoader = trendLoader ?? _loadTrend,
        _tagLoader = tagLoader ?? _loadTag;

  final PopularTrendLoader _trendLoader;
  final PopularTagLoader _tagLoader;

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

  /// The most recent recoverable load failure. Its changes are paired with
  /// [isLoadingMore], so MobX observers rebuild without another generated atom.
  String? loadError;

  static Future<List<BangumiItem>> _loadTrend(int offset) {
    final mirrorEnabled = GStorage.getSetting(SettingsKeys.enableBangumiProxy);
    return mirrorEnabled
        ? BangumiApi.getBangumiMirrorPopularSubjects(offset: offset)
        : BangumiApi.getBangumiTrendsList(offset: offset);
  }

  static Future<List<BangumiItem>> _loadTag(String tag, int offset) {
    final mirrorEnabled = GStorage.getSetting(SettingsKeys.enableBangumiProxy);
    return mirrorEnabled
        ? BangumiApi.getBangumiMirrorPopularSubjects(
            tag: tag,
            offset: offset,
          )
        : BangumiApi.getBangumiList(
            rank: Random().nextInt(8000) + 1,
            tag: tag,
          );
  }

  void setCurrentTag(String s) {
    currentTag = s;
  }

  void clearBangumiList() {
    bangumiList.clear();
  }

  // Async actions commit each segment between awaits as one transaction,
  // batching the completion writes into a single notification.
  @action
  Future<void> queryBangumiByTrend({String type = 'add'}) async {
    if (type == 'init') {
      trendList.clear();
    }
    isLoadingMore = true;
    isTimeOut = false;
    loadError = null;
    try {
      final result = await _trendLoader(trendList.length);
      trendList.addAll(result);
      isTimeOut = trendList.isEmpty;
    } catch (error, stackTrace) {
      loadError = '加载热门番组失败，请重试';
      isTimeOut = trendList.isEmpty;
      KazumiLogger().w(
        'PopularController: failed to load trending subjects',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      isLoadingMore = false;
    }
  }

  @action
  Future<void> queryBangumiByTag({String type = 'add'}) async {
    if (type == 'init') {
      bangumiList.clear();
    }
    isLoadingMore = true;
    isTimeOut = false;
    loadError = null;
    try {
      final result = await _tagLoader(currentTag, bangumiList.length);
      bangumiList.addAll(result);
      isTimeOut = bangumiList.isEmpty;
    } catch (error, stackTrace) {
      loadError = '加载标签番组失败，请重试';
      isTimeOut = bangumiList.isEmpty;
      KazumiLogger().w(
        'PopularController: failed to load subjects by tag',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      isLoadingMore = false;
    }
  }
}
