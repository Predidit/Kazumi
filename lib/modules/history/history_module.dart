import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/playback/playback_source.dart';

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

  @HiveField(7, defaultValue: 'online')
  String sourceTypeName;

  @HiveField(8, defaultValue: '')
  String localVideoPath;

  @HiveField(9, defaultValue: '')
  String localVideoTitle;

  @HiveField(10, defaultValue: '')
  String localVideoFileName;

  bool get isLocalVideo => sourceTypeName == PlaybackSourceType.localFile.name;

  bool get isBoundLocalVideo => isLocalVideo && bangumiItem.id > 0;

  String get key => isLocalVideo
      ? '$adapterName$localVideoPath'
      : adapterName + bangumiItem.id.toString();

  History(this.bangumiItem, this.lastWatchEpisode, this.adapterName,
      this.lastWatchTime, this.lastSrc, this.lastWatchEpisodeName,
      {this.sourceTypeName = 'online',
      this.localVideoPath = '',
      this.localVideoTitle = '',
      this.localVideoFileName = ''});

  static String getKey(String n, BangumiItem s,
      {String sourceTypeName = 'online', String localVideoPath = ''}) {
    return sourceTypeName == PlaybackSourceType.localFile.name
        ? '$n$localVideoPath'
        : n + s.id.toString();
  }

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

  @HiveField(3, defaultValue: '')
  String localPath;

  @HiveField(4, defaultValue: '')
  String episodeTitle;

  Duration get progress => Duration(milliseconds: _progressInMilli);

  set progress(Duration d) => _progressInMilli = d.inMilliseconds;

  Progress(
    this.episode,
    this.road,
    this._progressInMilli, {
    this.localPath = '',
    this.episodeTitle = '',
  });

  @override
  String toString() {
    return 'Episode ${episode.toString()}, progress $progress';
  }
}
