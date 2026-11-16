import 'dart:convert';

import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';

/// 用户手动选定并记住的弹幕源。
///
/// 自动匹配可能选错番剧或集号，用户在「选择弹幕源」面板手动选定并成功加载
/// 后，这里按 BgmBangumiID 记住所选弹幕源，之后切换到同一部剧集的其它分集时
/// 会直接沿用该弹幕源的对应集，无需重复手动选择。
class DanmakuSourceMemory {
  const DanmakuSourceMemory({
    required this.animeId,
    required this.episodeNumber,
    required this.bgmEpisodeNumber,
  });

  /// DanDanPlay 弹幕源番剧 ID。
  final int animeId;

  /// 选择时在弹幕源中选中的集号。
  final int episodeNumber;

  /// 选择时正在播放的 Bgm 集号，用于与弹幕源集号对齐。
  final int bgmEpisodeNumber;

  /// 依据当前播放的 Bgm 集号推算弹幕源中的集号。
  int episodeFor(int bgmEpisode) =>
      bgmEpisode + (episodeNumber - bgmEpisodeNumber);

  /// 读取指定剧集已记住的弹幕源，未记住或数据损坏时返回 null。
  static DanmakuSourceMemory? read(int bgmBangumiId) {
    try {
      final raw = GStorage.getStringSettingByName(_key(bgmBangumiId));
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final animeId = data['animeId'];
      final episodeNumber = data['episodeNumber'];
      final bgmEpisodeNumber = data['bgmEpisodeNumber'];
      if (animeId is int && episodeNumber is int && bgmEpisodeNumber is int) {
        return DanmakuSourceMemory(
          animeId: animeId,
          episodeNumber: episodeNumber,
          bgmEpisodeNumber: bgmEpisodeNumber,
        );
      }
    } catch (error) {
      KazumiLogger().w('Danmaku source memory failed to read', error: error);
    }
    return null;
  }

  /// 记住用户手动选定且加载成功的弹幕源。
  ///
  /// [animeId] 为弹幕源番剧 ID，[episodeNumber] 为所选弹幕源集号，
  /// [bgmEpisodeNumber] 为选择时正在播放的 Bgm 集号；二者之差作为集号偏移，
  /// 保证后续分集仍能对齐到同一弹幕源的对应集。
  static Future<void> remember({
    required int bgmBangumiId,
    required int animeId,
    required int episodeNumber,
    required int bgmEpisodeNumber,
  }) async {
    final payload = jsonEncode({
      'animeId': animeId,
      'episodeNumber': episodeNumber,
      'bgmEpisodeNumber': bgmEpisodeNumber,
    });
    try {
      await GStorage.putStringSettingByName(_key(bgmBangumiId), payload);
    } catch (error) {
      KazumiLogger().w('Danmaku source memory failed to save', error: error);
    }
  }

  static String _key(int bgmBangumiId) => 'danmakuManualSource_$bgmBangumiId';
}
