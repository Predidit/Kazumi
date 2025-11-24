import 'package:kazumi/modules/roads/cached_road_list.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:mobx/mobx.dart';

part 'video_source_repository.g.dart';

/// 视频源数据访问接口
///
/// 提供视频源播放列表的查询、缓存等功能
abstract class IVideoSourceRepository {
  /// 预加载播放列表
  ///
  /// [src] 视频源URL
  /// [plugin] 插件实例
  Future<void> preloadRoadList(String src, Plugin plugin);

  /// 批量预加载播放列表
  ///
  /// [sources] 视频源URL列表，每个元素是 (src, plugin) 元组
  Future<void> batchPreloadRoadLists(List<(String, Plugin)> sources);

  /// 获取播放列表
  ///
  /// [src] 视频源URL
  /// 返回缓存的播放列表数据，不存在返回null
  CachedRoadList? getRoadList(String src);

  /// 查询并缓存播放列表
  ///
  /// [src] 视频源URL
  /// [plugin] 插件实例
  /// 如果已有缓存且成功，直接返回缓存；否则重新查询
  Future<CachedRoadList> queryRoadList(String src, Plugin plugin);

  /// 获取播放列表加载状态
  ///
  /// [src] 视频源URL
  RoadListLoadStatus getLoadStatus(String src);

  /// 清空指定视频源的缓存
  ///
  /// [src] 视频源URL
  void clearCache(String src);

  /// 批量清空指定视频源列表的缓存
  ///
  /// [sources] 视频源URL列表
  void clearCacheBatch(List<String> sources);

  /// 清空所有缓存
  void clearAllCache();

  /// 清空所有过期缓存
  ///
  /// [maxAge] 最大缓存时长，默认1小时
  void clearExpiredCache({Duration maxAge = const Duration(hours: 1)});

  /// 强制刷新指定视频源的播放列表
  ///
  /// [src] 视频源URL
  /// [plugin] 插件实例
  /// 清除缓存并重新加载
  Future<CachedRoadList> refreshRoadList(String src, Plugin plugin);

  /// 获取缓存的视频源数量
  int getCacheSize();
}

/// 视频源数据访问实现类
///
/// 基于内存缓存实现的视频源数据访问层，使用 MobX 进行响应式状态管理
class VideoSourceRepository = _VideoSourceRepository with _$VideoSourceRepository;

abstract class _VideoSourceRepository with Store implements IVideoSourceRepository {
  /// 内存缓存：src -> CachedRoadList（响应式）
  @observable
  ObservableMap<String, CachedRoadList> cache = ObservableMap<String, CachedRoadList>();

  /// 正在加载的任务：src -> Future
  final Map<String, Future<CachedRoadList>> _pendingTasks = {};

  /// 最大缓存条目数（防止内存泄漏）
  static const int maxCacheSize = 100;

  /// 默认缓存过期时间（1小时）
  static const Duration defaultMaxAge = Duration(hours: 1);

  @override
  @action
  Future<void> preloadRoadList(String src, Plugin plugin) async {
    try {
      // 检查缓存：有效且未过期则跳过
      final cached = cache[src];
      if (cached?.isSuccess == true && !cached!.isExpired(maxAge: defaultMaxAge)) {
        return;
      }

      // 如果正在加载中，跳过
      if (_pendingTasks.containsKey(src)) {
        return;
      }

      // 内存保护：如果缓存过多，先清理过期缓存
      if (cache.length >= maxCacheSize) {
        clearExpiredCache();
        // 如果清理后仍然过多，清理最旧的缓存
        if (cache.length >= maxCacheSize) {
          _evictOldestCache();
        }
      }

      // 标记为加载中
      cache[src] = CachedRoadList.pending();

      // 创建加载任务
      final task = _loadRoadList(src, plugin);
      _pendingTasks[src] = task;

      // 执行加载
      await task;
    } catch (e) {
      KazumiLogger().log(
        Level.warning,
        '预加载播放列表失败: $src',
        error: e,
      );
    } finally {
      // 清理加载任务
      _pendingTasks.remove(src);
    }
  }

  @override
  Future<void> batchPreloadRoadLists(List<(String, Plugin)> sources) async {
    final tasks = sources.map((item) {
      final (src, plugin) = item;
      return preloadRoadList(src, plugin);
    }).toList();

    await Future.wait(tasks, eagerError: false);
  }

  @override
  CachedRoadList? getRoadList(String src) {
    final cached = cache[src];
    // 如果缓存过期，返回 null（视为不存在）
    if (cached != null && cached.isExpired(maxAge: defaultMaxAge)) {
      return null;
    }
    return cached;
  }

  @override
  @action
  Future<CachedRoadList> queryRoadList(String src, Plugin plugin) async {
    try {
      // 检查缓存：有效且未过期则直接返回
      final cached = cache[src];
      if (cached != null && cached.isSuccess && !cached.isExpired(maxAge: defaultMaxAge)) {
        return cached;
      }

      // 如果正在加载中，等待加载完成
      if (_pendingTasks.containsKey(src)) {
        return await _pendingTasks[src]!;
      }

      // 内存保护
      if (cache.length >= maxCacheSize) {
        clearExpiredCache();
        if (cache.length >= maxCacheSize) {
          _evictOldestCache();
        }
      }

      // 标记为加载中
      cache[src] = CachedRoadList.pending();

      // 创建加载任务
      final task = _loadRoadList(src, plugin);
      _pendingTasks[src] = task;

      try {
        return await task;
      } finally {
        _pendingTasks.remove(src);
      }
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '查询播放列表失败: $src',
        error: e,
        stackTrace: stackTrace,
      );

      final errorCache = CachedRoadList.error(e.toString());
      cache[src] = errorCache;
      return errorCache;
    }
  }

  @override
  RoadListLoadStatus getLoadStatus(String src) {
    final cached = cache[src];
    if (cached == null) {
      return RoadListLoadStatus.notStarted;
    }
    return cached.status;
  }

  @override
  @action
  void clearCache(String src) {
    cache.remove(src);
    _pendingTasks.remove(src);
  }

  @override
  @action
  void clearCacheBatch(List<String> sources) {
    for (final src in sources) {
      cache.remove(src);
      _pendingTasks.remove(src);
    }
    KazumiLogger().log(Level.debug, '批量清理了 ${sources.length} 个缓存');
  }

  @override
  @action
  void clearAllCache() {
    cache.clear();
    _pendingTasks.clear();
  }

  @override
  @action
  void clearExpiredCache({Duration maxAge = const Duration(hours: 1)}) {
    final keysToRemove = <String>[];

    for (final entry in cache.entries) {
      if (entry.value.isExpired(maxAge: maxAge)) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      cache.remove(key);
      _pendingTasks.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      KazumiLogger().log(Level.debug, '清理了 ${keysToRemove.length} 个过期缓存');
    }
  }

  @override
  int getCacheSize() {
    return cache.length;
  }

  /// 内部方法：清理最旧的缓存（LRU策略）
  @action
  void _evictOldestCache() {
    if (cache.isEmpty) return;

    // 找到最旧的缓存
    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in cache.entries) {
      // 跳过正在加载中的
      if (entry.value.isPending) continue;

      if (oldestTime == null || entry.value.timestamp.isBefore(oldestTime)) {
        oldestTime = entry.value.timestamp;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      cache.remove(oldestKey);
      _pendingTasks.remove(oldestKey);
      KazumiLogger().log(Level.debug, '缓存已满，清理了最旧的缓存: $oldestKey');
    }
  }

  @override
  @action
  Future<CachedRoadList> refreshRoadList(String src, Plugin plugin) async {
    // 先清除旧缓存
    clearCache(src);

    KazumiLogger().log(Level.info, '强制刷新播放列表: $src');

    // 重新加载
    return await queryRoadList(src, plugin);
  }

  /// 内部方法：加载播放列表
  @action
  Future<CachedRoadList> _loadRoadList(String src, Plugin plugin) async {
    try {
      final roadList = await plugin.querychapterRoads(src);
      final cached = CachedRoadList.success(roadList);
      cache[src] = cached;
      return cached;
    } catch (e) {
      final errorCache = CachedRoadList.error(e.toString());
      cache[src] = errorCache;
      rethrow;
    }
  }
}
