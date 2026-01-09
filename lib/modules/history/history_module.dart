import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

part 'history_module.g.dart';

@HiveType(typeId: 1)
class History {
  @HiveField(0)
  Map<int, Progress> progresses = {};

  @HiveField(1)
  int lastWatchEpisode;

  @HiveField(2)
  String adapterName;

  @HiveField(3)
  BangumiItem bangumiItem;

  @HiveField(4)
  DateTime lastWatchTime;

  @HiveField(5)
  String lastSrc;

  @HiveField(6, defaultValue: '')
  String lastWatchEpisodeName;

  String get key => adapterName + bangumiItem.id.toString();

  History(
      this.bangumiItem, this.lastWatchEpisode, this.adapterName, this.lastWatchTime, this.lastSrc, this.lastWatchEpisodeName);

  static String getKey(String n, BangumiItem s) => n + s.id.toString();

  @override
  String toString() {
    return 'Adapter: $adapterName, anime: ${bangumiItem.name}';
  }
}

@HiveType(typeId: 2)
class Progress {
  @HiveField(0)
  int episode;

  @HiveField(1)
  int road;

  @HiveField(2)
  int _progressInMilli;

  Duration get progress => Duration(milliseconds: _progressInMilli);

  set progress(Duration d) => _progressInMilli = d.inMilliseconds;

  Progress(this.episode, this.road, this._progressInMilli);

  @override
  String toString() {
    return 'Episode ${episode.toString()}, progress $progress';
  }
}
