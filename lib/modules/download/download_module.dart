import 'package:hive_ce/hive.dart';

part 'download_module.g.dart';

@HiveType(typeId: 7)
class DownloadRecord {
  @HiveField(0)
  int bangumiId;

  @HiveField(1)
  String bangumiName;

  @HiveField(2)
  String bangumiCover;

  @HiveField(3)
  String pluginName;

  @HiveField(4)
  Map<int, DownloadEpisode> episodes;

  @HiveField(5)
  DateTime createdAt;

  String get key => '${pluginName}_$bangumiId';

  /// 生成复合 key: road * 100000 + episodeNumber
  /// 用于在 episodes map 中区分不同 road 的同号集数
  static int episodeKey(int road, int episodeNumber) =>
      road * 100000 + episodeNumber;

  DownloadRecord(
    this.bangumiId,
    this.bangumiName,
    this.bangumiCover,
    this.pluginName,
    this.episodes,
    this.createdAt,
  );
}

@HiveType(typeId: 8)
class DownloadEpisode {
  @HiveField(0)
  int episodeNumber;

  @HiveField(1)
  String episodeName;

  @HiveField(2)
  int road;

  /// 0=pending 1=resolving 2=downloading 3=completed 4=failed 5=paused
  @HiveField(3)
  int status;

  @HiveField(4)
  double progressPercent;

  @HiveField(5)
  int totalSegments;

  @HiveField(6)
  int downloadedSegments;

  @HiveField(7)
  String localM3u8Path;

  @HiveField(8)
  String downloadDirectory;

  @HiveField(9)
  String networkM3u8Url;

  @HiveField(10)
  DateTime? completedAt;

  @HiveField(11, defaultValue: '')
  String errorMessage;

  @HiveField(12, defaultValue: 0)
  int totalBytes;

  @HiveField(13, defaultValue: '')
  String episodePageUrl;

  /// 缓存的弹幕数据 (JSON 字符串格式)
  @HiveField(14, defaultValue: '')
  String danmakuData;

  /// DanDanPlay 番剧 ID (用于弹幕查询缓存)
  @HiveField(15, defaultValue: 0)
  int danDanBangumiID;

  /// 视频源详情页 URL (如 /voddetail/25443.html)，用于下载管理页分组显示
  @HiveField(16, defaultValue: '')
  String sourceDetailUrl;

  /// 视频源详情页标题 (如 "JOJO的奇妙冒险 石之海")，用于下载管理页分组标题
  @HiveField(17, defaultValue: '')
  String sourceTitle;

  DownloadEpisode(
    this.episodeNumber,
    this.episodeName,
    this.road,
    this.status,
    this.progressPercent,
    this.totalSegments,
    this.downloadedSegments,
    this.localM3u8Path,
    this.downloadDirectory,
    this.networkM3u8Url,
    this.completedAt,
    this.errorMessage,
    this.totalBytes,
    this.episodePageUrl, {
    this.danmakuData = '',
    this.danDanBangumiID = 0,
    this.sourceDetailUrl = '',
    this.sourceTitle = '',
  });
}

class DownloadStatus {
  static const int pending = 0;
  static const int resolving = 1;
  static const int downloading = 2;
  static const int completed = 3;
  static const int failed = 4;
  static const int paused = 5;
}
