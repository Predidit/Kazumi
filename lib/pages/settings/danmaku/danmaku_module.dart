import 'package:kazumi/pages/settings/danmaku/danmaku_settings.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_settings.dart';

class DanmakuModule extends Module {
  @override
  void binds(i) {}

  @override
  void routes(r) {
    r.child("/", child: (_) => const DanmakuSettingsPage());
    r.child("/shield", child: (_) => const DanmakuShieldSettings());
  }
}
