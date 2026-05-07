import 'package:kazumi/modules/bangumi/bangumi_item.dart';

const String localVideoHistoryAdapterName = 'local_video';

enum PlaybackSourceType {
  online,
  downloaded,
  localFile,
}

class LocalVideoPlaybackContext {
  final String path;
  final String title;
  final String fileName;
  final int fileSize;
  final DateTime? lastModified;
  final BangumiItem? boundBangumiItem;
  final int? boundEpisode;

  const LocalVideoPlaybackContext({
    required this.path,
    required this.title,
    required this.fileName,
    required this.fileSize,
    required this.lastModified,
    this.boundBangumiItem,
    this.boundEpisode,
  });

  bool get hasBangumiBinding => boundBangumiItem != null;

  LocalVideoPlaybackContext copyWith({
    String? title,
    BangumiItem? boundBangumiItem,
    int? boundEpisode,
    bool clearBangumiBinding = false,
  }) {
    return LocalVideoPlaybackContext(
      path: path,
      title: title ?? this.title,
      fileName: fileName,
      fileSize: fileSize,
      lastModified: lastModified,
      boundBangumiItem: clearBangumiBinding
          ? null
          : boundBangumiItem ?? this.boundBangumiItem,
      boundEpisode:
          clearBangumiBinding ? null : boundEpisode ?? this.boundEpisode,
    );
  }
}
