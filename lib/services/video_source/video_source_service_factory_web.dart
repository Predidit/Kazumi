import 'package:kazumi/services/video_source/remote_video_source_service.dart';
import 'package:kazumi/services/video_source/video_source_service.dart';

IVideoSourceService createPlatformVideoSourceService() {
  return RemoteVideoSourceService();
}
