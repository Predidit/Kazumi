import 'package:auto_injector/auto_injector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/pages/about/about_page.dart';
import 'package:kazumi/pages/about/credits_page.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/download/download_page.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/history/history_page.dart';
import 'package:kazumi/pages/logs/logs_page.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/plugin_editor/plugin_editor_page.dart';
import 'package:kazumi/pages/plugin_editor/plugin_shop_page.dart';
import 'package:kazumi/pages/plugin_editor/plugin_test_page.dart';
import 'package:kazumi/pages/plugin_editor/plugin_view_page.dart';
import 'package:kazumi/pages/route_error_page.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_settings.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_settings.dart';
import 'package:kazumi/pages/settings/decoder_settings.dart';
import 'package:kazumi/pages/settings/displaymode_settings.dart';
import 'package:kazumi/pages/settings/download_settings.dart';
import 'package:kazumi/pages/settings/interface_settings.dart';
import 'package:kazumi/pages/settings/keyboard_settings.dart';
import 'package:kazumi/pages/settings/player_settings.dart';
import 'package:kazumi/pages/settings/proxy/proxy_editor_page.dart';
import 'package:kazumi/pages/settings/proxy/proxy_settings_page.dart';
import 'package:kazumi/pages/settings/renderer_settings.dart';
import 'package:kazumi/pages/settings/settings_navigation.dart';
import 'package:kazumi/pages/settings/settings_page.dart';
import 'package:kazumi/pages/settings/storage_settings.dart';
import 'package:kazumi/pages/settings/super_resolution_settings.dart';
import 'package:kazumi/pages/settings/sync/bangumi_sync_page.dart';
import 'package:kazumi/pages/settings/sync/sync_settings_page.dart';
import 'package:kazumi/pages/settings/sync/webdav_server_page.dart';
import 'package:kazumi/pages/settings/sync/webdav_sync_page.dart';
import 'package:kazumi/pages/settings/theme_settings_page.dart';
import 'package:kazumi/pages/settings/update_settings.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/services/collection/collection_service.dart';
import 'package:kazumi/services/player/history_playback_service.dart';

List<RouteBase> settingsRoutes(AutoInjector dependencies) {
  final navigatorKey = GlobalKey<NavigatorState>();
  return [
    ShellRoute(
      notifyRootObserver: false,
      navigatorKey: navigatorKey,
      builder: (context, state, child) => SettingsVisitScope(
        extra: state.extra,
        child: SettingsPage(
          location: state.uri.path,
          navigatorKey: navigatorKey,
          child: child,
        ),
      ),
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsIndexPage(),
        ),
        GoRoute(
          path: '/settings/sync',
          builder: (context, state) => const SyncSettingsPage(),
        ),
        GoRoute(
          path: '/settings/bangumi',
          builder: (context, state) => BangumiSyncPage(
            collection: dependencies.get<CollectionService>(),
          ),
        ),
        GoRoute(
          path: '/settings/webdav',
          builder: (context, state) => const WebDavSyncPage(),
        ),
        GoRoute(
          path: '/settings/webdav/editor',
          builder: (context, state) => const WebDavServerPage(),
        ),
        GoRoute(
          path: '/settings/update',
          builder: (context, state) => const UpdateSettingsPage(),
        ),
        GoRoute(
          path: '/settings/storage',
          builder: (context, state) => const StorageSettingsPage(),
        ),
        GoRoute(
          path: '/settings/storage/logs',
          builder: (context, state) => const LogsPage(),
        ),
        GoRoute(
          path: '/settings/theme',
          builder: (context, state) => ThemeSettingsPage(
              themeProvider: dependencies.get<ThemeProvider>()),
        ),
        GoRoute(
          path: '/settings/theme/display',
          builder: (context, state) => const SetDisplayMode(),
        ),
        GoRoute(
          path: '/settings/keyboard',
          builder: (context, state) => const KeyboardSettingsPage(),
        ),
        GoRoute(
          path: '/settings/player',
          builder: (context, state) => const PlayerSettingsPage(),
        ),
        GoRoute(
          path: '/settings/player/decoder',
          builder: (context, state) => const DecoderSettings(),
        ),
        GoRoute(
          path: '/settings/player/renderer',
          builder: (context, state) => const RendererSettings(),
        ),
        GoRoute(
          path: '/settings/player/super',
          builder: (context, state) => const SuperResolutionSettings(),
        ),
        GoRoute(
          path: '/settings/interface',
          builder: (context, state) => const InterfaceSettingsPage(),
        ),
        GoRoute(
          path: '/settings/proxy',
          builder: (context, state) => const ProxySettingsPage(),
        ),
        GoRoute(
          path: '/settings/proxy/editor',
          builder: (context, state) => const ProxyEditorPage(),
        ),
        GoRoute(
          path: '/settings/about',
          builder: (context, state) => AboutPage(
            onCheckUpdate: dependencies.get<MyController>().checkUpdate,
          ),
        ),
        GoRoute(
          path: '/settings/about/credits',
          builder: (context, state) => const CreditsPage(),
        ),
        GoRoute(
          path: '/settings/plugin',
          builder: (context, state) => PluginViewPage(
            controller: dependencies.get<PluginsController>(),
          ),
        ),
        GoRoute(
          path: '/settings/plugin/shop',
          builder: (context, state) => PluginShopPage(
            controller: dependencies.get<PluginsController>(),
          ),
        ),
        GoRoute(
          path: '/settings/plugin/test',
          builder: (context, state) {
            final plugin = state.extra;
            return plugin is Plugin
                ? PluginTestPage(plugin: plugin)
                : const RouteErrorPage(message: '规则测试参数无效，请返回后重试。');
          },
        ),
        GoRoute(
          path: '/settings/plugin/editor',
          builder: (context, state) {
            final plugin = state.extra;
            return plugin is Plugin
                ? PluginEditorPage(
                    plugin: plugin,
                    controller: dependencies.get<PluginsController>(),
                  )
                : const RouteErrorPage(message: '规则编辑参数无效，请返回后重试。');
          },
        ),
        GoRoute(
          path: '/settings/danmaku',
          builder: (context, state) => const DanmakuSettingsPage(),
        ),
        GoRoute(
          path: '/settings/danmaku/shield',
          builder: (context, state) => DanmakuShieldSettings(
              controller: dependencies.get<MyController>()),
        ),
        GoRoute(
          path: '/settings/download-settings',
          builder: (context, state) => const DownloadSettingsPage(),
        ),
      ],
    ),
    // These pages cover the settings shell on the root navigator.
    GoRoute(
      path: '/settings/about/license',
      builder: (context, state) => const LicensePage(
        applicationName: 'Kazumi',
        applicationVersion: ApiEndpoints.version,
        applicationLegalese: 'Kazumi · GNU General Public License v3.0',
      ),
    ),
    GoRoute(
      path: '/settings/history',
      builder: (context, state) => HistoryPage(
          collectController: dependencies.get<CollectController>(),
          playbackService: dependencies.get<HistoryPlaybackService>(),
          controller: dependencies.get<HistoryController>()),
    ),
    GoRoute(
      path: '/settings/download',
      builder: (context, state) =>
          DownloadPage(controller: dependencies.get<DownloadController>()),
    ),
  ];
}
