import 'package:kazumi/pages/video/video_page.dart';
import 'package:flutter_modular/flutter_modular.dart';

class VideoModule extends Module {
  @override
  void routes(r) {
    r.child("/", child: (_) => const VideoPage());
  }
}
