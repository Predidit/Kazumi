import 'package:kazumi/providers/video_source_provider.dart';
import 'package:kazumi/repositories/download_repository.dart';
import 'package:kazumi/utils/download_manager.dart';
import 'package:kazumi/modules/download/download_module.dart';

/// 缓存视频源提供者
///
/// 从本地下载缓存中读取视频源。
/// 如果指定的视频已下载完成，返回本地路径；否则抛出 [VideoSourceNotFoundException]。
class CachedVideoSourceProvider implements IVideoSourceProvider {
  final IDownloadRepository _repository;
  final IDownloadManager _downloadManager;

  /// 番剧 ID
  final int bangumiId;

  /// 插件名称
  final String pluginName;

  /// 集数编号
  final int episodeNumber;

  CachedVideoSourceProvider({
    required IDownloadRepository repository,
    required IDownloadManager downloadManager,
    required this.bangumiId,
    required this.pluginName,
    required this.episodeNumber,
  })  : _repository = repository,
        _downloadManager = downloadManager;

  @override
  Future<VideoSource> resolve(
    String episodeUrl, {
    required bool useLegacyParser,
    int offset = 0,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final localPath = _getLocalVideoPath();

    if (localPath != null) {
      return VideoSource(
        url: localPath,
        offset: offset,
        type: VideoSourceType.cached,
      );
    }

    throw VideoSourceNotFoundException(
      'No cached video for bangumi $bangumiId, plugin $pluginName, episode $episodeNumber',
    );
  }

  /// 从 DownloadRepository 获取本地视频路径
  String? _getLocalVideoPath() {
    final episode = _repository.getEpisode(bangumiId, pluginName, episodeNumber);
    if (episode == null) return null;

    // 只有下载完成的视频才返回路径
    if (episode.status != DownloadStatus.completed) return null;

    return _downloadManager.getLocalVideoPath(episode);
  }

  @override
  void cancel() {
    // 缓存读取是同步的，无需取消
  }

  @override
  void dispose() {
    // 无资源需要释放
  }
}
