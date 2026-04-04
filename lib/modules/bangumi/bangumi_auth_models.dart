import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/utils.dart';

class BangumiAuthUser {
  final String username;
  final String nickname;
  final String avatar;

  const BangumiAuthUser({
    required this.username,
    required this.nickname,
    required this.avatar,
  });

  factory BangumiAuthUser.fromJson(Map<String, dynamic> json) {
    final avatarData = json['avatar'];
    String avatar = '';
    if (avatarData is Map<String, dynamic>) {
      avatar = (avatarData['large'] ??
              avatarData['medium'] ??
              avatarData['small'] ??
              '')
          .toString();
    }
    return BangumiAuthUser(
      username: (json['username'] ?? '').toString(),
      nickname: ((json['nickname'] ?? json['username']) ?? '').toString(),
      avatar: avatar,
    );
  }
}

class BangumiSubjectCollection {
  final int subjectId;
  final int type;
  final int epStatus;
  final BangumiAuthCollectionSubject? subject;

  const BangumiSubjectCollection({
    required this.subjectId,
    required this.type,
    required this.epStatus,
    this.subject,
  });

  factory BangumiSubjectCollection.fromJson(Map<String, dynamic> json) {
    return BangumiSubjectCollection(
      subjectId: json['subject_id'] ?? 0,
      type: json['type'] ?? 0,
      epStatus: json['ep_status'] ?? 0,
      subject: json['subject'] is Map<String, dynamic>
          ? BangumiAuthCollectionSubject.fromJson(
              Map<String, dynamic>.from(json['subject']))
          : null,
    );
  }
}

class BangumiAuthCollectionSubject {
  final int id;
  final int type;
  final String name;
  final String nameCn;
  final String summary;
  final String date;
  final Map<String, String> images;
  final int rank;
  final double score;
  final int total;

  const BangumiAuthCollectionSubject({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.date,
    required this.images,
    required this.rank,
    required this.score,
    required this.total,
  });

  factory BangumiAuthCollectionSubject.fromJson(Map<String, dynamic> json) {
    return BangumiAuthCollectionSubject(
      id: json['id'] ?? 0,
      type: json['type'] ?? 2,
      name: (json['name'] ?? '').toString(),
      nameCn: (json['name_cn'] ?? '').toString(),
      summary: (json['short_summary'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      images: json['images'] is Map<String, dynamic>
          ? Map<String, String>.from(json['images'])
          : <String, String>{
              'large': '',
              'common': '',
              'medium': '',
              'small': '',
              'grid': '',
            },
      rank: json['rank'] ?? 0,
      score: ((json['score'] ?? 0) as num).toDouble(),
      total: json['collection_total'] ?? 0,
    );
  }

  BangumiItem toBangumiItem() {
    return BangumiItem(
      id: id,
      type: type,
      name: name,
      nameCn: nameCn,
      summary: summary,
      airDate: date,
      airWeekday: Utils.dateStringToWeekday(date.isEmpty ? '2000-11-11' : date),
      rank: rank,
      images: images,
      tags: const [],
      alias: const [],
      ratingScore: score,
      votes: total,
      votesCount: const [],
      info: '',
    );
  }
}

class BangumiEpisodeCollection {
  final int episodeId;
  final int type;

  const BangumiEpisodeCollection({
    required this.episodeId,
    required this.type,
  });

  factory BangumiEpisodeCollection.fromJson(Map<String, dynamic> json) {
    final episode = json['episode'];
    int episodeId = 0;
    if (episode is Map<String, dynamic>) {
      episodeId = episode['id'] ?? 0;
    }
    return BangumiEpisodeCollection(
      episodeId: episodeId,
      type: json['type'] ?? 0,
    );
  }
}
