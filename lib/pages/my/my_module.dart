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
    r.child("/theme", child: (_) => const ThemeSettingsPage(), transition: TransitionType.noTransition);
    r.child("/theme/display",
        child: (_) => const SetDiaplayMode(),
        transition: TransitionType.noTransition);
    r.child(
      "/danmaku",
      child: (_) => const DanmakuSettingsPage(),
      transition: TransitionType.noTransition
    );
    r.child("/player", child: (_) => const PlayerSettingsPage(), transition: TransitionType.noTransition);
    r.child("/other", child: (_) => const OtherSettingsPage(), transition: TransitionType.noTransition);
    r.module("/webdav", module: WebDavModule(), transition: TransitionType.noTransition);
    r.module("/about", module: AboutModule(), transition: TransitionType.noTransition);
    r.module("/plugin", module: PluginModule(), transition: TransitionType.noTransition);
    r.module("/history", module: HistoryModule(), transition: TransitionType.noTransition);
  }
}
