import 'package:hive_ce/hive.dart';

part 'bangumi_tag.g.dart';

@HiveType(typeId: 4)
class BangumiTag {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final int count;
  @HiveField(2)
  final int totalCount;

  BangumiTag({
    required this.name,
    required this.count,
    required this.totalCount,
  });

  factory BangumiTag.fromJson(Map<String, dynamic> json) {
    return BangumiTag(
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
      totalCount: json['total_cont'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'count': count,
      'total_cont': totalCount,
    };
  }
}