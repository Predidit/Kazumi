import 'package:kazumi/services/video_source/video_source_service.dart';
import 'package:kazumi/services/video_source/webview_video_source_service.dart';

IVideoSourceService createPlatformVideoSourceService() {
  return WebViewVideoSourceService();
}
