// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_source_repository.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$VideoSourceRepository on _VideoSourceRepository, Store {
  late final _$cacheAtom =
      Atom(name: '_VideoSourceRepository.cache', context: context);

  @override
  ObservableMap<String, CachedRoadList> get cache {
    _$cacheAtom.reportRead();
    return super.cache;
  }

  @override
  set cache(ObservableMap<String, CachedRoadList> value) {
    _$cacheAtom.reportWrite(value, super.cache, () {
      super.cache = value;
    });
  }

  late final _$preloadRoadListAsyncAction =
      AsyncAction('_VideoSourceRepository.preloadRoadList', context: context);

  @override
  Future<void> preloadRoadList(String src, Plugin plugin) {
    return _$preloadRoadListAsyncAction
        .run(() => super.preloadRoadList(src, plugin));
  }

  late final _$queryRoadListAsyncAction =
      AsyncAction('_VideoSourceRepository.queryRoadList', context: context);

  @override
  Future<CachedRoadList> queryRoadList(String src, Plugin plugin) {
    return _$queryRoadListAsyncAction
        .run(() => super.queryRoadList(src, plugin));
  }

  late final _$refreshRoadListAsyncAction =
      AsyncAction('_VideoSourceRepository.refreshRoadList', context: context);

  @override
  Future<CachedRoadList> refreshRoadList(String src, Plugin plugin) {
    return _$refreshRoadListAsyncAction
        .run(() => super.refreshRoadList(src, plugin));
  }

  late final _$_loadRoadListAsyncAction =
      AsyncAction('_VideoSourceRepository._loadRoadList', context: context);

  @override
  Future<CachedRoadList> _loadRoadList(String src, Plugin plugin) {
    return _$_loadRoadListAsyncAction
        .run(() => super._loadRoadList(src, plugin));
  }

  late final _$_VideoSourceRepositoryActionController =
      ActionController(name: '_VideoSourceRepository', context: context);

  @override
  void clearCache(String src) {
    final _$actionInfo = _$_VideoSourceRepositoryActionController.startAction(
        name: '_VideoSourceRepository.clearCache');
    try {
      return super.clearCache(src);
    } finally {
      _$_VideoSourceRepositoryActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearCacheBatch(List<String> sources) {
    final _$actionInfo = _$_VideoSourceRepositoryActionController.startAction(
        name: '_VideoSourceRepository.clearCacheBatch');
    try {
      return super.clearCacheBatch(sources);
    } finally {
      _$_VideoSourceRepositoryActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearAllCache() {
    final _$actionInfo = _$_VideoSourceRepositoryActionController.startAction(
        name: '_VideoSourceRepository.clearAllCache');
    try {
      return super.clearAllCache();
    } finally {
      _$_VideoSourceRepositoryActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearExpiredCache({Duration maxAge = defaultMaxAge}) {
    final _$actionInfo = _$_VideoSourceRepositoryActionController.startAction(
        name: '_VideoSourceRepository.clearExpiredCache');
    try {
      return super.clearExpiredCache(maxAge: maxAge);
    } finally {
      _$_VideoSourceRepositoryActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _evictOldestCache() {
    final _$actionInfo = _$_VideoSourceRepositoryActionController.startAction(
        name: '_VideoSourceRepository._evictOldestCache');
    try {
      return super._evictOldestCache();
    } finally {
      _$_VideoSourceRepositoryActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
cache: ${cache}
    ''';
  }
}
