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
    r.child("/theme", child: (_) => const ThemeSettingsPage());
    r.child("/theme/display",
        child: (_) => const SetDiaplayMode(),
        transition: TransitionType.leftToRight);
    r.child(
      "/danmaku",
      child: (_) => const DanmakuSettingsPage(),
    );
    r.child("/player", child: (_) => const PlayerSettingsPage());
    r.child("/other", child: (_) => const OtherSettingsPage());
    r.module("/webdav", module: WebDavModule());
    r.module("/about", module: AboutModule());
    r.module("/plugin", module: PluginModule());
    r.module("/history", module: HistoryModule());
  }
}
