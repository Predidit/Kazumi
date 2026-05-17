import 'package:kazumi/modules/comments/comment_item.dart';

class BangumiInterest {
  final int id;

  final int rate;

  final int type;

  final String comment;

  final List<String> tags;

  final int epStatus;

  final int volStatus;

  final int updatedAt;

  final User? user;

  BangumiInterest({
    required this.id,
    required this.rate,
    required this.type,
    required this.comment,
    required this.tags,
    required this.epStatus,
    required this.volStatus,
    required this.updatedAt,
    this.user,
  });


  bool get hasUserProfile => user != null;

  BangumiInterest copyWithUser({User? user}) {
    return BangumiInterest(
      id: id,
      rate: rate,
      type: type,
      comment: comment,
      tags: tags,
      epStatus: epStatus,
      volStatus: volStatus,
      updatedAt: updatedAt,
      user: user ?? this.user,
    );
  }

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
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  factory BangumiInterest.mergeLocalSubmission({
    BangumiInterest? previous,
    required int rate,
    required String comment,
    required List<String> tags,
  }) {
    return BangumiInterest(
      id: previous?.id ?? 0,
      rate: rate,
      type: previous?.type ?? 0,
      comment: comment,
      tags: List<String>.from(tags),
      epStatus: previous?.epStatus ?? 0,
      volStatus: previous?.volStatus ?? 0,
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      user: previous?.user,
    );
  }

  @override
  String toString() {
    return 'BangumiInterest{id: $id, rate: $rate, type: $type, comment: $comment, tags: $tags, epStatus: $epStatus, volStatus: $volStatus, updatedAt: $updatedAt, user: $user}';
  }
}