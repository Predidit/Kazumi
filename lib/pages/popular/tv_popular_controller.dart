import 'dart:math';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:mobx/mobx.dart';

/// TV category state; mobile and desktop keep the upstream controller.
class TvPopularController extends PopularController {
  int _tagQueryGeneration = 0;
  int _activeLoadingRequests = 0;
  // Small session cache of metadata only; images keep their own cache.
  final _tagCache = <(bool, String), (DateTime, List<BangumiItem>)>{};
  static const _tagCacheLifetime = Duration(minutes: 10);
  static const _maxCachedTags = 8;
  static const _maxCachedItems = 240;

  bool get _bangumiMirrorEnabled =>
      GStorage.getSetting(SettingsKeys.enableBangumiProxy);

  void _beginLoading() {
    _activeLoadingRequests += 1;
    isLoadingMore = true;
  }

  void _endLoading() {
    if (_activeLoadingRequests > 0) {
      _activeLoadingRequests -= 1;
    }
    isLoadingMore = _activeLoadingRequests > 0;
  }

  @override
  void setCurrentTag(String s) {
    if (s != currentTag) _tagQueryGeneration += 1;
    currentTag = s;
  }

  @override
  Future<void> queryBangumiByTag({String type = 'add'}) =>
      AsyncAction('TvPopularController.queryBangumiByTag').run(() async {
        final cacheKey = (_bangumiMirrorEnabled, currentTag);
        if (type == 'init') {
          _tagQueryGeneration += 1;
          final cached = _tagCache.remove(cacheKey);
          if (cached != null &&
              DateTime.now().difference(cached.$1) < _tagCacheLifetime) {
            _tagCache[cacheKey] = cached;
            bangumiList = ObservableList.of(cached.$2);
            isTimeOut = false;
            return;
          }
          bangumiList.clear();
        }
        final requestGeneration = _tagQueryGeneration;
        _beginLoading();
        var tag = currentTag;
        try {
          var result = _bangumiMirrorEnabled
              ? await BangumiApi.getBangumiMirrorPopularSubjects(
                  tag: tag,
                  offset: bangumiList.length,
                )
              : await BangumiApi.getBangumiList(
                  rank: Random().nextInt(8000) + 1,
                  tag: tag,
                );
          if (requestGeneration != _tagQueryGeneration || tag != currentTag) {
            return;
          }
          bangumiList.addAll(result);
          isTimeOut = bangumiList.isEmpty;
          if (bangumiList.isNotEmpty) {
            _tagCache.remove(cacheKey);
            _tagCache[cacheKey] = (
              DateTime.now(),
              bangumiList.take(_maxCachedItems).toList(growable: false),
            );
            while (_tagCache.length > _maxCachedTags) {
              _tagCache.remove(_tagCache.keys.first);
            }
          }
        } finally {
          _endLoading();
        }
      });
}
