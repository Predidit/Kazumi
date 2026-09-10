import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_settings.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_settings.dart';

final danmakuModule = createModule(
  path: '/danmaku',
  register: (c) {
    c
      ..route('/', child: (context, state) => const DanmakuSettingsPage())
      ..route(
        '/shield',
        child: (context, state) => const DanmakuShieldSettings(),
      );
  },
);
