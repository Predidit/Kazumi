import 'package:kazumi/services/storage/storage.dart';

/// 自定义弹幕服务器的配置解析。
///
/// 兼容的服务端实现了弹弹play v2 接口契约（如 danmu_api / LogVar 弹幕 API）：
/// - GET  {base}/api/v2/search/episodes?anime=xxx
/// - GET  {base}/api/v2/bangumi/{animeId}
/// - GET  {base}/api/v2/comment/{episodeId}
/// - POST {base}/api/v2/match
///
/// base URL 可携带 token 路径段，例如 http://192.168.1.7:9321/87654321 。
class CustomDanmakuServerConfig {
  const CustomDanmakuServerConfig._();

  /// 是否配置了可用的自定义弹幕服务器。
  static bool get isEnabled {
    if (!GStorage.getSetting(SettingsKeys.customDanmakuServerEnable)) {
      return false;
    }
    return baseUrl != null;
  }

  /// 归一化后的 base URL（无结尾斜杠、无 /api/v2 后缀），不可用时为 null。
  static String? get baseUrl =>
      normalizeBaseUrl(GStorage.getSetting(SettingsKeys.customDanmakuServerUrl));

  /// 播放时是否按标题自动匹配弹幕。
  static bool get autoMatch =>
      GStorage.getSetting(SettingsKeys.customDanmakuServerAutoMatch);

  /// 归一化用户输入：
  /// - 去除首尾空白与结尾斜杠
  /// - 去掉结尾的 /api/v2 段（客户端总是自行拼接）
  /// - 仅接受带 host 的 http(s) 地址
  static String? normalizeBaseUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) {
      return null;
    }
    url = url.replaceAll(RegExp(r'/+$'), '');
    url = url.replaceAll(RegExp(r'/api/v2$'), '');
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }
    return url;
  }
}
