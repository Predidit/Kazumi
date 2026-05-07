class BangumiInterest {
  final int id;
  final int rate;
  final int type;
  final String comment;
  final List<String> tags;
  final int epStatus;
  final int volStatus;
  final bool private;
  final int updatedAt;

  BangumiInterest({
    required this.id,
    required this.rate,
    required this.type,
    required this.comment,
    required this.tags,
    required this.epStatus,
    required this.volStatus,
    required this.private,
    required this.updatedAt,
  });

  factory BangumiInterest.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    final List<String> tagList = [];
    if (tagsRaw is List) {
      for (final e in tagsRaw) {
        if (e is String) {
          tagList.add(e);
        } else if (e is Map && e['name'] != null) {
          tagList.add(e['name'].toString());
        }
      }
    }
    return BangumiInterest(
      id: (json['id'] as num).toInt(),
      rate: (json['rate'] as num?)?.toInt() ?? 0,
      type: (json['type'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String? ?? '',
      tags: tagList,
      epStatus: (json['epStatus'] as num?)?.toInt() ?? 0,
      volStatus: (json['volStatus'] as num?)?.toInt() ?? 0,
      private: json['private'] as bool? ?? false,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() {
    return 'BangumiInterest{id: $id, rate: $rate, type: $type, comment: $comment, tags: $tags, epStatus: $epStatus, volStatus: $volStatus, private: $private, updatedAt: $updatedAt}';
  }
}