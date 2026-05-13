import 'dart:async';

import 'package:synchronized/synchronized.dart';

import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/providers/video/video_source_provider.dart';
import 'package:kazumi/providers/video/webview_video_source_provider.dart';
import 'package:kazumi/utils/logger.dart';

/// 让 LAN HTTP server 复用宿主的 WebView 视频源解析能力。
///
/// [WebViewVideoSourceProvider] 同实例不能并发（内部用 `_resolveId` 互踢），
/// 所以这里用一个 [Lock] 把所有 LAN 来源的 resolve 调用排队执行。
/// 桌面端用户本人在 Kazumi UI 里看番时另开了一个 provider 实例，跟这里互不
/// 影响（虽然底层 WebView 资源仍是共享的，但目前看库内部实现允许多实例共存）。
class LanSourceResolver {
  LanSourceResolver();

  final Lock _lock = Lock();
  WebViewVideoSourceProvider? _provider;

  Future<VideoSource> resolve({
    required Plugin plugin,
    required String episodeUrl,
    Duration timeout = const Duration(seconds: 20),
  }) {
    return _lock.synchronized(() async {
      _provider ??= WebViewVideoSourceProvider();
      try {
        final source = await _provider!.resolve(
          episodeUrl,
          useLegacyParser: plugin.useLegacyParser,
          timeout: timeout,
        );
        KazumiLogger().i(
            'LanSourceResolver: resolved ${plugin.name} -> ${source.url}');
        return source;
      } catch (e) {
        KazumiLogger().w(
            'LanSourceResolver: resolve failed for ${plugin.name}', error: e);
        rethrow;
      }
    });
  }

  Future<void> dispose() async {
    await _lock.synchronized(() async {
      _provider?.dispose();
      _provider = null;
    });
  }
}
