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

  DownloadRecord(
    this.bangumiId,
    this.bangumiName,
    this.bangumiCover,
    this.pluginName,
    this.episodes,
    this.createdAt,
  );
}

const int _maxDownloadKey = 0x7fffffff;

/// 新下载记录的 Hive map key。
///
/// [DownloadEpisode.episodeNumber] 保留“集序数”语义；`DownloadRecord.episodes`
/// 的 key 仅作为本地下载任务/目录/缓存定位 key。新记录优先由 stableId 派生，
/// 避免同一个 ordinal 的不同集互相覆盖；旧记录缺 stableId 时继续使用集序数。
int downloadKeyForEpisodeIdentity(
  DownloadRecord record, {
  required int episodeNumber,
  required int road,
  required String stableId,
}) {
  final id = stableId.trim();
  if (id.isEmpty) {
    return episodeNumber;
  }
  var key = stableDownloadKey(_stableDownloadScopedId(id, road));
  while (true) {
    final existing = record.episodes[key];
    if (existing == null ||
        (existing.stableId == id && existing.road == road)) {
      return key;
    }
    key = key == _maxDownloadKey ? 1 : key + 1;
  }
}

String _stableDownloadScopedId(String stableId, int road) => '$road\n$stableId';

int stableDownloadKey(String stableId) {
  var hash = 0x811c9dc5;
  for (final codeUnit in stableId.trim().codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & _maxDownloadKey;
  }
  return hash == 0 ? 1 : hash;
}

MapEntry<int, DownloadEpisode>? downloadEpisodeEntryByStableId(
  DownloadRecord record,
  String stableId, {
  required int road,
}) {
  final id = stableId.trim();
  if (id.isEmpty) {
    return null;
  }
  for (final entry in record.episodes.entries) {
    if (entry.value.stableId == id && entry.value.road == road) {
      return entry;
    }
  }
  return null;
}

/// 旧下载记录没有 [DownloadEpisode.stableId] 时的迁移匹配入口。
///
/// 新链路不再把 URL 当作下载身份；这里仅允许用当前规则身份的 pageUrl
/// 命中“stableId 为空”的旧记录，然后由调用方写入 stableId。
MapEntry<int, DownloadEpisode>? legacyDownloadEpisodeEntryForStableIdBackfill(
  DownloadRecord record, {
  required String episodePageUrl,
  required int road,
}) {
  final pageUrl = episodePageUrl.trim();
  if (pageUrl.isEmpty) {
    return null;
  }
  for (final entry in record.episodes.entries) {
    final episode = entry.value;
    if (episode.stableId.isEmpty &&
        episode.road == road &&
        episode.episodePageUrl == pageUrl) {
      return entry;
    }
  }
  return null;
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

  /// 订阅规则产出的稳定集身份；用于下载查重与在线/离线身份互通。
  @HiveField(16, defaultValue: '')
  String stableId;

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
    this.stableId = '',
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
