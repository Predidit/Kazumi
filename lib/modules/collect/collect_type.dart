/// 收藏类型枚举
///
/// 用于标识番剧的收藏状态
enum CollectType {
  /// 未收藏
  none(0, '未收藏'),

  /// 在看
  watching(1, '在看'),

  /// 想看
  planToWatch(2, '想看'),

  /// 搁置
  onHold(3, '搁置'),

  /// 看过
  watched(4, '看过'),

  /// 抛弃
  abandoned(5, '抛弃');

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

  /// NOICE：与bgm对不上 1想看 2看过 3在看 4搁置 5抛弃; 本地 0未收藏 1在看 2想看 3搁置 4看过 5抛弃
  
  /// 将bangumi的收藏状态转为本地收藏状态
  static CollectType fromBangumi(int value) {
    return switch (value) {
      1 => CollectType.planToWatch,
      2 => CollectType.watched,
      3 => CollectType.watching,
      4 => CollectType.onHold,
      5 => CollectType.abandoned,
      _ => CollectType.none,
    };
  }

  /// 将本地收藏状态转为bangumi的收藏状态
  int toBangumi() {
    return switch (this) {
      CollectType.planToWatch => 1,
      CollectType.watched => 2,
      CollectType.watching => 3,
      CollectType.onHold => 4,
      CollectType.abandoned => 5,
      _ => 0,
    };
  }

  /// 是否为有效的收藏状态（排除未收藏）
  bool get isCollected => this != CollectType.none;
}
