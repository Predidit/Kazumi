/// Bangumi 收藏类型枚举。
enum BangumiCollectionType {
  unknown(0, '未知'),

  /// 想看
  planToWatch(1, '想看'),

  /// 看过
  watched(2, '看过'),

  /// 在看
  watching(3, '在看'),

  /// 搁置
  onHold(4, '搁置'),

  /// 抛弃
  abandoned(5, '抛弃');

  const BangumiCollectionType(this.value, this.label);

  final int value;
  final String label;

  static BangumiCollectionType fromValue(int value) {
    return BangumiCollectionType.values.firstWhere(
          (type) => type.value == value,
      orElse: () => BangumiCollectionType.unknown,
    );
  }
}
