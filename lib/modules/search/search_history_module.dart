import 'package:hive_ce/hive.dart';

part 'search_history_module.g.dart';

@HiveType(typeId: 6)
class SearchHistory {
  @HiveField(0)
  String keyword;

  @HiveField(1)
  int timestamp;

  SearchHistory(this.keyword, this.timestamp);

  String get key => timestamp.toString();

  @override
  String toString() {
    return 'Search keyword: $keyword, search time: ${DateTime.fromMillisecondsSinceEpoch(timestamp)}';
  }
}