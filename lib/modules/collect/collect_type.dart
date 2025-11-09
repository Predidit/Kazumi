/// 收藏类型枚举
///
/// 用于标识番剧的收藏状态
enum CollectType {
  /// 未收藏
  none(0, '未收藏'),

  /// 正在观看
  watching(1, '正在观看'),

  /// 计划观看
  planToWatch(2, '计划观看'),

  /// 搁置中
  onHold(3, '搁置中'),

  /// 已看过
  watched(4, '已看过'),

  /// 已抛弃
  abandoned(5, '已抛弃');

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
