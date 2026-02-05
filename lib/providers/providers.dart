/// Video Source Provider 模块
///
/// 提供视频源解析的抽象层，支持：
/// - WebView 在线解析
///
/// 使用示例：
/// ```dart
/// final provider = WebViewVideoSourceProvider();
/// try {
///   final source = await provider.resolve(
///     episodeUrl,
///     useLegacyParser: false,
///   );
///   print('Video URL: ${source.url}');
/// } on VideoSourceTimeoutException {
///   print('解析超时');
/// } finally {
///   provider.dispose();
/// }
/// ```
library;

export 'video_source_provider.dart';
export 'webview_video_source_provider.dart';
