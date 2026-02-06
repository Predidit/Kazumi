import 'package:kazumi/pages/video/video_page.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/player/player_controller.dart';

class VideoModule extends Module {
  @override
  void routes(r) {
    r.child("/", child: (_) => const VideoPage());
  }

  @override
  void binds(i) {
    i.addSingleton(PlayerController.new);
  }
}
