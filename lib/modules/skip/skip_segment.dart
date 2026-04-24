enum SkipSegmentType {
  opening,
  ending,
}

class SkipSegmentTemplate {
  final int bangumiId;
  final String pluginName;
  final int road;
  final int sourceEpisode;
  final SkipSegmentType type;
  final Duration start;
  final Duration end;
  final DateTime createdAt;

  const SkipSegmentTemplate({
    required this.bangumiId,
    required this.pluginName,
    required this.road,
    required this.sourceEpisode,
    required this.type,
    required this.start,
    required this.end,
    required this.createdAt,
  });

  Duration get duration => end - start;

  String get key => keyOf(
        bangumiId: bangumiId,
        pluginName: pluginName,
        type: type,
      );

  static String keyOf({
    required int bangumiId,
    required String pluginName,
    required SkipSegmentType type,
  }) {
    return '$bangumiId:$pluginName:${type.name}';
  }

  void validate() {
    if (bangumiId <= 0) {
      throw ArgumentError.value(bangumiId, 'bangumiId');
    }
    if (pluginName.isEmpty) {
      throw ArgumentError.value(pluginName, 'pluginName');
    }
    if (road < 0) {
      throw ArgumentError.value(road, 'road');
    }
    if (sourceEpisode <= 0) {
      throw ArgumentError.value(sourceEpisode, 'sourceEpisode');
    }
    if (start.isNegative) {
      throw ArgumentError.value(start, 'start');
    }
    if (end <= start) {
      throw ArgumentError.value(end, 'end');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'bangumiId': bangumiId,
      'pluginName': pluginName,
      'road': road,
      'sourceEpisode': sourceEpisode,
      'type': type.name,
      'startMs': start.inMilliseconds,
      'endMs': end.inMilliseconds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SkipSegmentTemplate.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? '';
    return SkipSegmentTemplate(
      bangumiId: (json['bangumiId'] as num).toInt(),
      pluginName: json['pluginName'].toString(),
      road: (json['road'] as num).toInt(),
      sourceEpisode: (json['sourceEpisode'] as num).toInt(),
      type: SkipSegmentType.values.firstWhere(
        (type) => type.name == typeName,
        orElse: () => throw ArgumentError.value(typeName, 'type'),
      ),
      start: Duration(milliseconds: (json['startMs'] as num).toInt()),
      end: Duration(milliseconds: (json['endMs'] as num).toInt()),
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }
}

class ResolvedSkipSegment {
  final SkipSegmentType type;
  final Duration start;
  final Duration end;
  final double score;
  final double confidence;
  final int sourceEpisode;

  const ResolvedSkipSegment({
    required this.type,
    required this.start,
    required this.end,
    required this.score,
    required this.confidence,
    required this.sourceEpisode,
  });

  Duration get duration => end - start;

  bool get isValid => end > start;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'startMs': start.inMilliseconds,
      'endMs': end.inMilliseconds,
      'score': score,
      'confidence': confidence,
      'sourceEpisode': sourceEpisode,
    };
  }
}
