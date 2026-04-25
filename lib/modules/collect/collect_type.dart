import '../bangumi/bangumi_collection_type.dart';

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

  /// Convert Bangumi's collect type to local collect type
  /// Bangumi [BangumiCollectionType] => Kazumi
  static CollectType fromBangumi(int value) {
    return BangumiCollectionType.fromValue(value).toCollectType();
  }

  BangumiCollectionType? toBangumiCollectionType() {
    return switch (this) {
      CollectType.planToWatch => BangumiCollectionType.planToWatch,
      CollectType.watched => BangumiCollectionType.watched,
      CollectType.watching => BangumiCollectionType.watching,
      CollectType.onHold => BangumiCollectionType.onHold,
      CollectType.abandoned => BangumiCollectionType.abandoned,
      CollectType.none => null,
    };
  }

  /// Convert local collect type to Bangumi's collect type
  /// Kazumi => Bangumi [BangumiCollectionType]
  int toBangumi() {
    return toBangumiCollectionType()?.value ?? 0;
  }

  /// 是否为有效的收藏状态（排除未收藏）
  bool get isCollected => this != CollectType.none;
}
