import 'package:kazumi/providers/video_source_provider.dart';
import 'package:kazumi/utils/logger.dart';

/// 组合视频源提供者
///
/// 按优先级尝试多个提供者：
/// 1. 首先尝试缓存提供者（如果配置了）
/// 2. 回退到 WebView 提供者
///
/// 这种策略确保已下载的视频优先使用本地缓存，减少网络请求和解析时间。
class CompositeVideoSourceProvider implements IVideoSourceProvider {
  final IVideoSourceProvider? _cacheProvider;
  final IVideoSourceProvider _webviewProvider;

  IVideoSourceProvider? _activeProvider;

  CompositeVideoSourceProvider({
    IVideoSourceProvider? cacheProvider,
    required IVideoSourceProvider webviewProvider,
  })  : _cacheProvider = cacheProvider,
        _webviewProvider = webviewProvider;

  @override
  Future<VideoSource> resolve(
    String episodeUrl, {
    required bool useNativePlayer,
    required bool useLegacyParser,
    int offset = 0,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // 1. 尝试缓存
    if (_cacheProvider != null) {
      try {
        _activeProvider = _cacheProvider;
        final result = await _cacheProvider.resolve(
          episodeUrl,
          useNativePlayer: useNativePlayer,
          useLegacyParser: useLegacyParser,
          offset: offset,
          timeout: timeout,
        );
        KazumiLogger().i('VideoSource: 使用本地缓存 ${result.url}');
        return result;
      } on VideoSourceNotFoundException {
        // 缓存未命中，继续尝试 WebView
        KazumiLogger().d('VideoSource: 缓存未命中，回退到 WebView');
      } catch (e) {
        // 其他错误也回退到 WebView
        KazumiLogger().w('VideoSource: 缓存读取失败 $e，回退到 WebView');
      }
    }

    // 2. WebView 解析
    _activeProvider = _webviewProvider;
    final result = await _webviewProvider.resolve(
      episodeUrl,
      useNativePlayer: useNativePlayer,
      useLegacyParser: useLegacyParser,
      offset: offset,
      timeout: timeout,
    );
    KazumiLogger().i('VideoSource: WebView 解析成功 ${result.url}');
    return result;
  }

  @override
  void cancel() {
    _activeProvider?.cancel();
    _activeProvider = null;
  }

  @override
  void dispose() {
    _cacheProvider?.dispose();
    _webviewProvider.dispose();
    _activeProvider = null;
  }
}
