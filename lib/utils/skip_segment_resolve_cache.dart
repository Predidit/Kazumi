import 'package:kazumi/modules/skip/skip_segment.dart';

class SkipSegmentResolveCacheKey {
  final int bangumiId;
  final String pluginName;
  final int episode;
  final SkipSegmentType type;

  const SkipSegmentResolveCacheKey({
    required this.bangumiId,
    required this.pluginName,
    required this.episode,
    required this.type,
  });

  @override
  bool operator ==(Object other) {
    return other is SkipSegmentResolveCacheKey &&
        other.bangumiId == bangumiId &&
        other.pluginName == pluginName &&
        other.episode == episode &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(bangumiId, pluginName, episode, type);

  @override
  String toString() => '$bangumiId:$pluginName:$episode:${type.name}';
}

class SkipSegmentResolveCache {
  final Map<SkipSegmentResolveCacheKey, ResolvedSkipSegment> _items = {};

  ResolvedSkipSegment? get(SkipSegmentResolveCacheKey key) {
    return _items[key];
  }

  void put(SkipSegmentResolveCacheKey key, ResolvedSkipSegment value) {
    _items[key] = value;
  }

  void clearEpisode({
    required int bangumiId,
    required String pluginName,
    required int episode,
  }) {
    _items.removeWhere((key, value) =>
        key.bangumiId == bangumiId &&
        key.pluginName == pluginName &&
        key.episode == episode);
  }

  void clear() {
    _items.clear();
  }
}
