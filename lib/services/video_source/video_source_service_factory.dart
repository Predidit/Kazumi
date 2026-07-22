import 'package:kazumi/services/video_source/video_source_service.dart';
import 'package:kazumi/services/video_source/video_source_service_factory_native.dart'
    if (dart.library.js_interop) 'package:kazumi/services/video_source/video_source_service_factory_web.dart'
    as platform;

/// Creates the resolver for the current compilation target without exposing
/// native WebView libraries to the web compiler.
IVideoSourceService createVideoSourceService() {
  return platform.createPlatformVideoSourceService();
}
