import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:mobx/mobx.dart';

part 'video_source_repository.g.dart';

/// 播放列表缓存状态
enum RoadListLoadStatus {
  pending,  // 加载中
  success,  // 成功
  error,    // 失败
  notStarted, // 未开始
}

/// 缓存的播放列表数据
class CachedRoadList {
  final List<Road> roadList;
  final RoadListLoadStatus status;
  final DateTime timestamp;
  final String? errorMessage;

  CachedRoadList({
    required this.roadList,
    required this.status,
    required this.timestamp,
    this.errorMessage,
  });

  /// 创建成功状态的缓存
  factory CachedRoadList.success(List<Road> roadList) {
    return CachedRoadList(
      roadList: roadList,
      status: RoadListLoadStatus.success,
      timestamp: DateTime.now(),
    );
  }

  /// 创建加载中状态的缓存
  factory CachedRoadList.pending() {
    return CachedRoadList(
      roadList: [],
      status: RoadListLoadStatus.pending,
      timestamp: DateTime.now(),
    );
  }

  /// 创建失败状态的缓存
  factory CachedRoadList.error(String errorMessage) {
    return CachedRoadList(
      roadList: [],
      status: RoadListLoadStatus.error,
      timestamp: DateTime.now(),
      errorMessage: errorMessage,
    );
  }

  bool get isSuccess => status == RoadListLoadStatus.success;
  bool get isPending => status == RoadListLoadStatus.pending;
  bool get isError => status == RoadListLoadStatus.error;
  bool get isNotStarted => status == RoadListLoadStatus.notStarted;
}

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

  /// 清空所有缓存
  void clearAllCache();

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

  @override
  @action
  Future<void> preloadRoadList(String src, Plugin plugin) async {
    try {
      // 如果已经有成功的缓存，跳过
      if (cache[src]?.isSuccess == true) {
        return;
      }

      // 如果正在加载中，跳过
      if (_pendingTasks.containsKey(src)) {
        return;
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
    return cache[src];
  }

  @override
  @action
  Future<CachedRoadList> queryRoadList(String src, Plugin plugin) async {
    try {
      // 如果已有成功的缓存，直接返回
      final cached = cache[src];
      if (cached != null && cached.isSuccess) {
        return cached;
      }

      // 如果正在加载中，等待加载完成
      if (_pendingTasks.containsKey(src)) {
        return await _pendingTasks[src]!;
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
  void clearAllCache() {
    cache.clear();
    _pendingTasks.clear();
  }

  @override
  int getCacheSize() {
    return cache.length;
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
