/// Bangumi 收藏类型枚举
/// via: https://bangumi.github.io/api/#/model-CollectionType
enum BangumiCollectionType {
  unknown(0, '未知'),

  planToWatch(1, '想看'),

  watched(2, '看过'),

  watching(3, '在看'),

  onHold(4, '搁置'),

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
