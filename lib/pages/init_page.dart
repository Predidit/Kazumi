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
// import 'package:fvp/mdk.dart' as mdk;
import 'package:flutter/services.dart' show rootBundle;
import 'package:kazumi/utils/logger.dart';
// import 'package:path_provider/path_provider.dart';

class InitPage extends StatefulWidget {
  const InitPage({super.key});

  @override
  State<InitPage> createState() => _InitPageState();
}

class _InitPageState extends State<InitPage> {
  final PluginsController pluginsController = Modular.get<PluginsController>();
  final CollectController collectController = Modular.get<CollectController>();
  Box setting = GStorage.setting;

  // Future<File> _getLogFile() async {
  //   final directory = await getApplicationDocumentsDirectory();
  //   return File('${directory.path}/app_log.txt');
  // }

  // Future<void> writeLog(String message) async {
  //   final logFile = await _getLogFile();
  //   await logFile.writeAsString('$message\n', mode: FileMode.append);
  // }

  @override
  void initState() {
    _pluginInit();
    _webDavInit();
    _update();
    _migrateStorage();
    super.initState();
  }

  // migrate collect from old version (favorites)
  Future<void> _migrateStorage() async {
    await collectController.migrateCollect();
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
      await pluginsController.loadPlugins();
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
                      await pluginsController.loadPlugins();
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
      Modular.to.navigate('/tab/popular/');
    }
  }

  void _update() {
    bool autoUpdate = setting.get(SettingBoxKey.autoUpdate, defaultValue: true);
    if (autoUpdate) {
      Modular.get<MyController>().checkUpdata(type: 'auto');
    }
  }

  Future<void> _pluginUpdate() async {
    await pluginsController.queryPluginHTTPList();
    int count = 0;
    for (var plugin in pluginsController.pluginList) {
      for (var pluginHTTP in pluginsController.pluginHTTPList) {
        if (plugin.name == pluginHTTP.name) {
          if (plugin.version != pluginHTTP.version) {
            count++;
            break;
          }
        }
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
    return Scaffold(
      body: Container()
    );
  }
}
