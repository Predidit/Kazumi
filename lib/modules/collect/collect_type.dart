/// 收藏类型枚举
///
/// 用于标识番剧的收藏状态
enum CollectType {
  /// 未收藏
  none(0, 'Not collected'),

  /// 在看
  watching(1, 'Watching'),

  /// 想看
  planToWatch(2, 'Plan to watch'),

  /// 搁置
  onHold(3, 'On hold'),

  /// 看过
  watched(4, 'Watched'),

  /// 抛弃
  abandoned(5, 'Dropped');

  const CollectType(this.value, this.label);

  /// 数值表示
  final int value;

  /// 显示标签
  final String label;

  /// 根据数值获取枚举
  static CollectType fromValue(int value) {
    return CollectType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => CollectType.none,
    );
  }

  /// 是否为有效的收藏状态（排除未收藏）
  bool get isCollected => this != CollectType.none;
}
