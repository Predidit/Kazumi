import 'package:kazumi/pages/settings/danmaku/danmaku_module.dart';
import 'package:kazumi/pages/about/about_module.dart';
import 'package:kazumi/pages/plugin_editor/plugin_module.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/history/history_module.dart';
import 'package:kazumi/pages/settings/interface_settings.dart';
import 'package:kazumi/pages/settings/theme_settings_page.dart';
import 'package:kazumi/pages/settings/player_settings.dart';
import 'package:kazumi/pages/settings/displaymode_settings.dart';
import 'package:kazumi/pages/settings/decoder_settings.dart';
import 'package:kazumi/pages/settings/super_resolution_settings.dart';
import 'package:kazumi/pages/settings/proxy/proxy_module.dart';
import 'package:kazumi/pages/webdav_editor/webdav_module.dart';
import 'package:kazumi/pages/settings/keyboard_settings.dart';
import 'package:kazumi/pages/settings/download_settings.dart';
import 'package:kazumi/pages/download/download_page_module.dart';

class SettingsModule extends Module {
  @override
  void routes(r) {
    r.child("/theme", child: (_) => const ThemeSettingsPage());
    r.child(
      "/theme/display",
      child: (_) => const SetDisplayMode(),
    );
    r.child("/keyboard", child: (_) => const KeyboardSettingsPage());
    r.child("/player", child: (_) => const PlayerSettingsPage());
    r.child("/player/decoder", child: (_) => const DecoderSettings());
    r.child("/interface", child: (_) => const InterfaceSettingsPage());
    r.module("/proxy", module: ProxyModule());
    r.child("/player/super", child: (_) => const SuperResolutionSettings());
    r.module("/webdav", module: WebDavModule());
    r.module("/about", module: AboutModule());
    r.module("/plugin", module: PluginModule());
    r.module("/history", module: HistoryModule());
    r.module("/danmaku", module: DanmakuModule());
    r.module("/download", module: DownloadModule());
    r.child("/download-settings", child: (_) => const DownloadSettingsPage());
  }
}
