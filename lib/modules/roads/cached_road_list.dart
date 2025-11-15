import 'package:kazumi/modules/roads/road_module.dart';

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

  /// 检查缓存是否已过期
  ///
  /// [maxAge] 最大缓存时长，默认1小时
  bool isExpired({Duration maxAge = const Duration(hours: 1)}) {
    // pending 和 notStarted 状态不算过期
    if (isPending || isNotStarted) {
      return false;
    }

    final now = DateTime.now();
    final age = now.difference(timestamp);
    return age > maxAge;
  }
}
