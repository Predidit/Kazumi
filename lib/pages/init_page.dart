import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:logger/logger.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:flutter/services.dart' show rootBundle;
import 'package:kazumi/utils/logger.dart';

class InitPage extends StatefulWidget {
  const InitPage({super.key});

  @override
  State<InitPage> createState() => _InitPageState();
}

class _InitPageState extends State<InitPage> {
  final PluginsController pluginsController = Modular.get<PluginsController>();
  Box setting = GStorage.setting;

  @override
  void initState() {
    _fvpInit();
    _pluginInit();
    _webDavInit();
    _update();
    super.initState();
  }

  _fvpInit() async {
    bool hAenable =
        await setting.get(SettingBoxKey.hAenable, defaultValue: true);
    bool lowMemoryMode =
        await setting.get(SettingBoxKey.lowMemoryMode, defaultValue: false);
    if (hAenable) {
      if (lowMemoryMode) {
        fvp.registerWith(options: {
          'platforms': ['windows', 'linux'],
          'player': {
            'avio.reconnect': '1',
            'avio.reconnect_delay_max': '7',
            'buffer': '2000+10000',
          }
        });
      } else {
        fvp.registerWith(options: {
          'platforms': ['windows', 'linux'],
          'player': {
            'avio.reconnect': '1',
            'avio.reconnect_delay_max': '7',
            'buffer': '2000+1500000',
            'demux.buffer.ranges': '8',
          }
        });
      }
    } else {
      if (lowMemoryMode) {
        fvp.registerWith(options: {
          'video.decoders': ['FFmpeg'],
          'player': {
            'avio.reconnect': '1',
            'avio.reconnect_delay_max': '7',
            'buffer': '2000+10000',
          }
        });
      } else {
        fvp.registerWith(options: {
          'video.decoders': ['FFmpeg'],
          'player': {
            'avio.reconnect': '1',
            'avio.reconnect_delay_max': '7',
            'buffer': '2000+1500000',
            'demux.buffer.ranges': '8',
          }
        });
      }
    }
  }

  _webDavInit() async {
    bool webDavEnable =
        await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    bool webDavEnableFavorite = await setting
        .get(SettingBoxKey.webDavEnableFavorite, defaultValue: false);
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
        if (webDavEnableFavorite) {
          try {
            await webDav.downloadFavorite();
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

  _pluginInit() async {
    String statementsText = '';
    try {
      await pluginsController.loadPlugins();
      statementsText =
          await rootBundle.loadString("assets/statements/statements.txt");
      _pluginUpdate();
    } catch (_) {}
    if (pluginsController.pluginList.isEmpty) {
      SmartDialog.show(
        useAnimation: false,
        builder: (context) {
          return AlertDialog(
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
                  SmartDialog.dismiss();
                  Modular.to.navigate('/tab/popular/');
                },
                child: const Text('已阅读并同意'),
              ),
            ],
          );
        },
      );
    } else {
      Modular.to.navigate('/tab/popular/');
    }
  }

  _update() {
    bool autoUpdate = setting.get(SettingBoxKey.autoUpdate, defaultValue: true);
    if (autoUpdate) {
      Modular.get<MyController>().checkUpdata(type: 'auto');
    }
  }

  _pluginUpdate() async {
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
      SmartDialog.showToast('检测到 $count 条规则可以更新');
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
    return const RouterOutlet();
  }
}

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(title: const Text("Kazumi")),
      body: Center(
        child: SizedBox(
          height: 200,
          child: Flex(
            direction: Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: size.width * 0.6,
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.black12,
                  minHeight: 10,
                ),
              ),
              const Text("初始化中"),
            ],
          ),
        ),
      ),
    );
  }
}
