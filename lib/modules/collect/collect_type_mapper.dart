/// Conversion between Bangumi's remote collection types and this app's local collection types.
import 'package:kazumi/modules/bangumi/bangumi_collection_type.dart';
import 'package:kazumi/modules/collect/collect_type.dart';

/// Converts Bangumi API to a local [CollectType].
/// Example: `collectTypeFromBangumiValue(3)` returns [CollectType.watching]
CollectType collectTypeFromBangumiValue(int value) {
  return BangumiCollectionType.fromValue(value).toCollectType();
}

/// Extension methods for converting [BangumiCollectionType] to local [CollectType].
extension BangumiCollectionTypeMapper on BangumiCollectionType {

  /// Converts this Bangumi collection type to the equivalent local type.
  CollectType toCollectType() {
    return switch (this) {
      BangumiCollectionType.planToWatch => CollectType.planToWatch,
      BangumiCollectionType.watched => CollectType.watched,
      BangumiCollectionType.watching => CollectType.watching,
      BangumiCollectionType.onHold => CollectType.onHold,
      BangumiCollectionType.abandoned => CollectType.abandoned,
      BangumiCollectionType.unknown => CollectType.none,
    };
  }
}

/// Extension methods for converting [CollectType] to [BangumiCollectionType].
extension CollectTypeBangumiMapper on CollectType {

  /// Converts this local collection type to the equivalent Bangumi type.
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

  /// Converts this local collection type to a raw Bangumi API integer value.
  int toBangumi() {
    return toBangumiCollectionType()?.value ?? 0;
  }
}
