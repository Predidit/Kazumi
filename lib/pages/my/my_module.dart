import 'package:kazumi/pages/settings/danmaku_settings.dart';
import 'package:kazumi/pages/my/my_page.dart';
import 'package:kazumi/pages/about/about_module.dart';
import 'package:kazumi/pages/plugin_editor/plugin_module.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/history/history_module.dart';
import 'package:kazumi/pages/settings/theme_settings_page.dart';
import 'package:kazumi/pages/settings/player_settings.dart';
import 'package:kazumi/pages/settings/displaymode_settings.dart';
import 'package:kazumi/pages/settings/other_settings.dart';
import 'package:kazumi/pages/webdav_editor/webdav_module.dart';

class MyModule extends Module {
  @override
  void routes(r) {
    r.child("/", child: (_) => const MyPage());
    r.child("/theme", child: (_) => const ThemeSettingsPage(), transition: TransitionType.defaultTransition);
    r.child("/theme/display",
        child: (_) => const SetDiaplayMode(),
        transition: TransitionType.defaultTransition);
    r.child(
      "/danmaku",
      child: (_) => const DanmakuSettingsPage(),
      transition: TransitionType.defaultTransition
    );
    r.child("/player", child: (_) => const PlayerSettingsPage(), transition: TransitionType.defaultTransition);
    r.child("/other", child: (_) => const OtherSettingsPage(), transition: TransitionType.defaultTransition);
    r.module("/webdav", module: WebDavModule(), transition: TransitionType.defaultTransition);
    r.module("/about", module: AboutModule(), transition: TransitionType.defaultTransition);
    r.module("/plugin", module: PluginModule(), transition: TransitionType.defaultTransition);
    r.module("/history", module: HistoryModule(), transition: TransitionType.noTransition);
  }
}
