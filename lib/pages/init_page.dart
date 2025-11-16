import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:logger/logger.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:kazumi/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/shaders/shaders_controller.dart';

class InitPage extends StatefulWidget {
  const InitPage({super.key});

  @override
  State<InitPage> createState() => _InitPageState();
}

class _InitPageState extends State<InitPage> {
  final PluginsController pluginsController = Modular.get<PluginsController>();
  final CollectController collectController = Modular.get<CollectController>();
  final ShadersController shadersController = Modular.get<ShadersController>();
  final MyController myController = Modular.get<MyController>();
  Box setting = GStorage.setting;
  late final ThemeProvider themeProvider;

  @override
  void initState() {
    _pluginInit();
    _webDavInit();
    _migrateStorage();
    _loadShaders();
    _loadDanmakuShield();
    _update();
    themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    super.initState();
  }

  // migrate collect from old version (favorites)
  Future<void> _migrateStorage() async {
    await collectController.migrateCollect();
  }

  Future<void> _loadShaders() async {
    await shadersController.copyShadersToExternalDirectory();
  }

  Future<void> _loadDanmakuShield() async {
    myController.loadShieldList();
  }

  Future<void> _webDavInit() async {
    bool webDavEnable =
        await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    if (webDavEnable) {
      var webDav = WebDav();
      KazumiLogger().log(Level.info, '开始从WEBDAV同步记录');
      try {
        await webDav.init();
        try {
          await webDav.downloadAndPatchHistory();
          KazumiLogger().log(Level.info, '同步观看记录完成');
        } catch (e) {
          KazumiDialog.showToast(message:"同步观看记录失败 ${e.toString()}");
          //KazumiLogger().log(Level.error, '同步观看记录失败 ${e.toString()}');
        }
      } catch (e) {
        KazumiDialog.showToast(message:"初始化WebDav失败 ${e.toString()}");
        //KazumiLogger().log(Level.error, '初始化WebDav失败 ${e.toString()}');
      }
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
              title: const Text('免责声明'),
              scrollable: true,
              content: Text(statementsText),
              actions: [
                TextButton(
                  onPressed: () {
                    exit(0);
                  },
                  child: Text(
                    '退出',
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
                      Modular.to.navigate('/tab/popular/');
                      return;
                    }
                    _switchUpdateMirror();
                  },
                  child: const Text('已阅读并同意'),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Workaround for dynamic_color. dynamic_color need PlatformChannel to get color, it takes time.
      // setDynamic here to avoid white screen flash when themeMode is dark.
      themeProvider.setDynamic(
          setting.get(SettingBoxKey.useDynamicColor, defaultValue: false));
      Modular.to.navigate('/tab/popular/');
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
            title: const Text('更新镜像'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '您希望从哪里获取应用更新？',
                    textAlign: TextAlign.left,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Github镜像为大多数情况下的最佳选择。如果您使用F-Droid应用商店, 请选择F-Droid镜像。',
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
                  Modular.to.navigate('/tab/popular/');
                },
                child: const Text(
                  'Github',
                ),
              ),
              TextButton(
                onPressed: () {
                  setting.put(SettingBoxKey.autoUpdate, false);
                  KazumiDialog.dismiss();
                  Modular.to.navigate('/tab/popular/');
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
    // Don't check update when there is no plugin.
    // We will progress init workflow instead.
    await Future.delayed(const Duration(seconds: 1));
    if (pluginsController.pluginList.isNotEmpty) {
      bool autoUpdate =
          setting.get(SettingBoxKey.autoUpdate, defaultValue: true);
      if (autoUpdate) {
        Modular.get<MyController>().checkUpdate(type: 'auto');
      }
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
      KazumiDialog.showToast(message: '检测到 $count 条规则可以更新');
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
