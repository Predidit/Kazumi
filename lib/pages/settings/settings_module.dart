import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/about/about_module.dart';
import 'package:kazumi/pages/download/download_page_module.dart';
import 'package:kazumi/pages/history/history_module.dart';
import 'package:kazumi/pages/logs/logs_page.dart';
import 'package:kazumi/pages/plugin_editor/plugin_module.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_module.dart';
import 'package:kazumi/pages/settings/decoder_settings.dart';
import 'package:kazumi/pages/settings/displaymode_settings.dart';
import 'package:kazumi/pages/settings/download_settings.dart';
import 'package:kazumi/pages/settings/interface_settings.dart';
import 'package:kazumi/pages/settings/keyboard_settings.dart';
import 'package:kazumi/pages/settings/player_settings.dart';
import 'package:kazumi/pages/settings/proxy/proxy_module.dart';
import 'package:kazumi/pages/settings/renderer_settings.dart';
import 'package:kazumi/pages/settings/settings_page.dart';
import 'package:kazumi/pages/settings/storage_settings.dart';
import 'package:kazumi/pages/settings/super_resolution_settings.dart';
import 'package:kazumi/pages/settings/sync/bangumi_sync_page.dart';
import 'package:kazumi/pages/settings/sync/sync_settings_page.dart';
import 'package:kazumi/pages/settings/sync/webdav_server_page.dart';
import 'package:kazumi/pages/settings/sync/webdav_sync_page.dart';
import 'package:kazumi/pages/settings/theme_settings_page.dart';
import 'package:kazumi/pages/settings/update_settings.dart';

final settingsModule = createModule(
  path: '/settings',
  register: (c) {
    c.route(
      '/',
      child: (context, state) => const SettingsPage(),
      children: (sub) {
        sub
          ..route('/', child: (context, state) => const SettingsMenuPage())
          ..route('/sync', child: (context, state) => const SyncSettingsPage())
          ..route('/bangumi/',
              child: (context, state) => const BangumiSyncPage())
          ..route('/webdav/', child: (context, state) => const WebDavSyncPage())
          ..route('/webdav/editor',
              child: (context, state) => const WebDavServerPage())
          ..route(
            '/update',
            child: (context, state) => const UpdateSettingsPage(),
          )
          ..route('/storage',
              child: (context, state) => const StorageSettingsPage())
          ..route('/storage/logs', child: (context, state) => const LogsPage())
          ..route('/theme',
              child: (context, state) => const ThemeSettingsPage())
          ..route(
            '/theme/display',
            child: (context, state) => const SetDisplayMode(),
          )
          ..route(
            '/keyboard',
            child: (context, state) => const KeyboardSettingsPage(),
          )
          ..route('/player',
              child: (context, state) => const PlayerSettingsPage())
          ..route(
            '/player/decoder',
            child: (context, state) => const DecoderSettings(),
          )
          ..route(
            '/player/renderer',
            child: (context, state) => const RendererSettings(),
          )
          ..route(
            '/interface',
            child: (context, state) => const InterfaceSettingsPage(),
          )
          ..module(proxyModule)
          ..route(
            '/player/super',
            child: (context, state) => const SuperResolutionSettings(),
          )
          ..module(aboutModule)
          ..module(pluginModule)
          ..module(historyModule)
          ..module(danmakuModule)
          ..module(downloadModule)
          ..route(
            '/download-settings',
            child: (context, state) => const DownloadSettingsPage(),
          );
      },
    );
  },
);
