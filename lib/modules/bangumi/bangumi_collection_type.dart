/// Bangumi 收藏类型枚举
/// via: https://bangumi.github.io/api/#/model-CollectionType
enum BangumiCollectionType {
  unknown(0, 'Unknown'),

  planToWatch(1, 'Plan to watch'),

  watched(2, 'Watched'),

  watching(3, 'Watching'),

  onHold(4, 'On hold'),

  abandoned(5, 'Dropped');

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
