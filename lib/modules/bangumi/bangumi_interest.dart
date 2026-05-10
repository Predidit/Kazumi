import 'package:hive_ce/hive.dart';

part 'bangumi_interest.g.dart';

@HiveType(typeId: 9)
class BangumiInterest {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int rate;

  @HiveField(2)
  final int type;

  @HiveField(3)
  final String comment;

  @HiveField(4)
  final List<String> tags;

  @HiveField(5)
  final int epStatus;

  @HiveField(6)
  final int volStatus;

  @HiveField(7)
  final bool private;

  @HiveField(8)
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

  factory BangumiInterest.mergeLocalSubmission({
    BangumiInterest? previous,
    required int rate,
    required String comment,
    required List<String> tags,
    required bool private,
  }) {
    return BangumiInterest(
      id: previous?.id ?? 0,
      rate: rate,
      type: previous?.type ?? 0,
      comment: comment,
      tags: List<String>.from(tags),
      epStatus: previous?.epStatus ?? 0,
      volStatus: previous?.volStatus ?? 0,
      private: private,
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  @override
  String toString() {
    return 'BangumiInterest{id: $id, rate: $rate, type: $type, comment: $comment, tags: $tags, epStatus: $epStatus, volStatus: $volStatus, private: $private, updatedAt: $updatedAt}';
  }
}