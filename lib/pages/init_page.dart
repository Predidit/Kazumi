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
  Box setting = GStorage.setting;
  late final ThemeProvider themeProvider;

  @override
  void initState() {
    _pluginInit();
    _webDavInit();
    _update();
    _migrateStorage();
    _loadShaders();
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

  Future<void> _webDavInit() async {
    bool webDavEnable =
        await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    bool webDavEnableCollect = await setting
        .get(SettingBoxKey.webDavEnableCollect, defaultValue: false);
    if (webDavEnable) {
      var webDav = WebDav();
      KazumiLogger().log(Level.info, '开始从WEBDAV同步记录');
      try {
        await webDav.init();
        try {
          await webDav.downloadHistory();
          KazumiLogger().log(Level.info, '同步观看记录完成');
        } catch (e) {
          KazumiLogger().log(Level.error, '同步观看记录失败 ${e.toString()}');
        }
        if (webDavEnableCollect) {
          try {
            await webDav.downloadCollectibles();
            KazumiLogger().log(Level.info, '同步追番列表完成');
          } catch (e) {
            KazumiLogger().log(Level.error, '同步追番列表失败 ${e.toString()}');
          }
        }
      } catch (e) {
        KazumiLogger().log(Level.error, '初始化WebDav失败 ${e.toString()}');
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
                    Modular.to.navigate('/tab/popular/');
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

  Future<void> _update() async {
    bool autoUpdate = setting.get(SettingBoxKey.autoUpdate, defaultValue: true);
    if (autoUpdate) {
      await Future.delayed(const Duration(seconds: 1));
      Modular.get<MyController>().checkUpdata(type: 'auto');
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
    /// 适配平板设备
    Box setting = GStorage.setting;
    bool isWideScreen = MediaQuery.of(context).size.shortestSide >= 600 &&
        (MediaQuery.of(context).size.shortestSide /
                MediaQuery.of(context).size.longestSide >=
            9 / 16);
    if (isWideScreen) {
      KazumiLogger().log(Level.info, '当前设备宽屏');
    } else {
      KazumiLogger().log(Level.info, '当前设备非宽屏');
    }
    setting.put(SettingBoxKey.isWideScreen, isWideScreen);
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
