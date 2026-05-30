import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/services/sync/bangumi_sync_service.dart';
import 'package:kazumi/services/sync/webdav.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:kazumi/services/logging/logger.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/services/shaders/shader_asset_service.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/services/download/background_download_service.dart';
import 'package:kazumi/services/platform/windows_shortcut.dart';
import 'package:kazumi/services/platform/platform_environment_service.dart';

class InitPage extends StatefulWidget {
  const InitPage({super.key});

  @override
  State<InitPage> createState() => _InitPageState();
}

class _InitPageState extends State<InitPage> {
  final PluginsController pluginsController = Modular.get<PluginsController>();
  final CollectController collectController = Modular.get<CollectController>();
  final ShaderAssetService shaderAssetService =
      Modular.get<ShaderAssetService>();
  final MyController myController = Modular.get<MyController>();
  final DownloadController downloadController =
      Modular.get<DownloadController>();
  Box setting = GStorage.setting;
  late final ThemeProvider themeProvider;

  @override
  void initState() {
    super.initState();
    themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    _migrateStorage();
    _loadShaders();
    _loadDanmakuShield();
    _webDavInit();
    _bangumiInit();
    try {
      await downloadController.init();
      _setupBackgroundDownloadNavigation();
    } catch (e) {
      KazumiLogger().e('InitPage: downloadController.init() failed', error: e);
    }

    await _checkRunningOnX11();
    await _pluginInit();
    await _showShortcutDialog();

    _startDefaultPage();
    // delay to ensure that the default page is fully loaded
    await Future.delayed(const Duration(milliseconds: 500));
    _update();
  }

  void _setupBackgroundDownloadNavigation() {
    final backgroundService = BackgroundDownloadService();

    backgroundService.onNavigateToDownloadRequested = () {
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          if (Modular.to.path.contains('/download')) return;
          Modular.to.pushNamed('/settings/download/');
        } catch (e) {
          KazumiLogger()
              .w('InitPage: failed to navigate to download page', error: e);
        }
      });
    };

    backgroundService.onNotificationPermissionRequired = () async {
      final result = await KazumiDialog.show<bool>(
        clickMaskDismiss: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Notification permission required'),
            content: const Text(
              'Granting notification permission lets downloads show progress in the background and prevents the system from terminating download tasks.\n\n'
              'If denied, downloads still work but may be interrupted by the system when in the background.',
            ),
            actions: [
              TextButton(
                onPressed: () => KazumiDialog.dismiss(popWith: false),
                child: Text(
                  'Maybe later',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              TextButton(
                onPressed: () => KazumiDialog.dismiss(popWith: true),
                child: const Text('Allow'),
              ),
            ],
          );
        },
      );
      return result ?? false;
    };
  }

  void _startDefaultPage() {
    final defaultStartupPage = setting.get(
      SettingBoxKey.defaultStartupPage,
      defaultValue: '/tab/popular/',
    );
    // Workaround for dynamic_color. dynamic_color need PlatformChannel to get color, it takes time.
    // setDynamic here to avoid white screen flash when themeMode is dark.
    themeProvider.setDynamic(
        setting.get(SettingBoxKey.useDynamicColor, defaultValue: false));
    Modular.to.navigate(defaultStartupPage);
  }

  // migrate collect from old version (favorites)
  Future<void> _migrateStorage() async {
    await collectController.migrateCollect();
  }

  Future<void> _loadShaders() async {
    await shaderAssetService.copyShadersToExternalDirectory();
  }

  Future<void> _loadDanmakuShield() async {
    myController.loadShieldList();
  }

  Future<void> _webDavInit() async {
    bool webDavEnable =
        await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    if (webDavEnable) {
      var webDav = WebDav();
      KazumiLogger().i('WebDav: Starting WebDav initialization');
      try {
        await webDav.init();
        try {
          await webDav.syncHistory();
          KazumiLogger().i('WebDav: Completed syncing watch history');
        } catch (e, stackTrace) {
          KazumiLogger().w(
            'WebDav: automatic watch history sync failed',
            error: e,
            stackTrace: stackTrace,
          );
        }
      } catch (e, stackTrace) {
        KazumiLogger().w(
          'WebDav: automatic initialization failed',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _bangumiInit() async {
    bool bangumiEnable = await setting.get(
      SettingBoxKey.bangumiSyncEnable,
      defaultValue: false,
    );
    if (bangumiEnable) {
      var bangumi = BangumiSyncService();
      KazumiLogger().i('Bangumi: Starting Bangumi initialization');
      try {
        await bangumi.init();
      } catch (e) {
        bangumi.reset();
        await setting.put(SettingBoxKey.bangumiSyncEnable, false);
        KazumiLogger().w(
          'Bangumi: initialization failed, disabling Bangumi sync until user re-enables it',
          error: e,
        );
        KazumiDialog.showToast(
          message: 'Failed to initialize Bangumi, Bangumi sync has been disabled: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _checkRunningOnX11() async {
    if (!Platform.isLinux) {
      return;
    }
    bool isRunningOnX11 = await PlatformEnvironmentService.isRunningOnX11();
    if (isRunningOnX11) {
      await KazumiDialog.show(
        clickMaskDismiss: false,
        builder: (context) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('X11 environment detected'),
              content: const Text(
                  'You are currently running under X11. Kazumi may have performance issues or display glitches under X11, and switching to Wayland is recommended for a better experience. Do you want to continue using Kazumi under X11?'),
              actions: [
                TextButton(
                  onPressed: () {
                    exit(0);
                  },
                  child: Text(
                    'Exit',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    KazumiDialog.dismiss();
                  },
                  child: const Text('Resume'),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Future<void> _showShortcutDialog() async {
    if (!Platform.isWindows) return;
    if (setting.get(SettingBoxKey.shortcutDialogShown, defaultValue: false)) {
      return;
    }

    final create = await KazumiDialog.show<bool>(
      clickMaskDismiss: false,
      builder: (context) => AlertDialog(
        title: const Text('Create desktop shortcut'),
        content: const Text('Create a Kazumi shortcut on the desktop?'),
        actions: [
          TextButton(
            onPressed: () => KazumiDialog.dismiss(popWith: false),
            child: Text('Not now',
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ),
          TextButton(
            onPressed: () => KazumiDialog.dismiss(popWith: true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    await setting.put(SettingBoxKey.shortcutDialogShown, true);
    if (create ?? false) {
      final success = await WindowsShortcut.createDesktopShortcut();
      KazumiDialog.showToast(message: success ? 'Desktop shortcut created' : 'Failed to create desktop shortcut');
    }
  }

  Future<void> _pluginInit() async {
    String statementsText = '';
    try {
      await pluginsController.init();
      statementsText =
          await rootBundle.loadString("assets/statements/statements.txt");
      _pluginUpdate();
    } catch (_) {}
    if (pluginsController.pluginList.isEmpty) {
      await KazumiDialog.show(
        clickMaskDismiss: false,
        builder: (context) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('Disclaimer'),
              scrollable: true,
              content: Text(statementsText),
              actions: [
                TextButton(
                  onPressed: () {
                    exit(0);
                  },
                  child: Text(
                    'Exit',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await pluginsController.copyPluginsToExternalDirectory();
                    } catch (_) {}
                    KazumiDialog.dismiss();
                    if (!Platform.isAndroid) {
                      return;
                    }
                    await _switchUpdateMirror();
                  },
                  child: const Text('I have read and agree'),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  // The function is not completed yet
  // We simply disable update when the user is using F-Droid mirror
  // We are trying to meet F-Droid requirement to submit the app
  // After the app is submitted, we will complete the function
  Future<void> _switchUpdateMirror() async {
    await KazumiDialog.show(
      clickMaskDismiss: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Update mirror'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Where would you like to get app updates from?',
                    textAlign: TextAlign.left,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'The Github mirror is the best choice in most cases. If you use the F-Droid app store, please choose the F-Droid mirror.',
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setting.put(SettingBoxKey.autoUpdate, true);
                  KazumiDialog.dismiss();
                },
                child: const Text(
                  'Github',
                ),
              ),
              TextButton(
                onPressed: () {
                  setting.put(SettingBoxKey.autoUpdate, false);
                  KazumiDialog.dismiss();
                },
                child: Text(
                  'F-Droid',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _update() async {
    bool autoUpdate =
        await setting.get(SettingBoxKey.autoUpdate, defaultValue: true);
    if (autoUpdate) {
      Modular.get<MyController>().checkUpdate(type: 'auto');
    }
  }

  Future<void> _pluginUpdate() async {
    await pluginsController.queryPluginHTTPList();
    int count = 0;
    for (var plugin in pluginsController.pluginList) {
      if (pluginsController.pluginUpdateStatus(plugin) == 'updatable') {
        count++;
      }
    }
    if (count != 0) {
      KazumiDialog.showToast(message: '$count rules can be updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const LoadingWidget();
  }
}

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Container());
  }
}
