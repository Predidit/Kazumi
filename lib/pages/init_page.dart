import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

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
    _pluginInit();
    _webDavInit();
    super.initState();
  }

  _webDavInit() async {
    bool webDavEnable =
        setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    bool webDavEnableFavorite =
        setting.get(SettingBoxKey.webDavEnableFavorite, defaultValue: false);
    if (webDavEnable) {
      var webDav = WebDav();
      debugPrint('开始从WEBDAV同步记录');
      try {
        await webDav.init();
        try {
          await webDav.downloadHistory();
          debugPrint('同步观看记录完成');
        } catch (e) {
          debugPrint('同步观看记录失败 ${e.toString()}');
        }
        if (webDavEnableFavorite) {
          try {
            await webDav.downloadFavorite();
            debugPrint('同步追番列表完成');
          } catch (e) {
            debugPrint('同步追番列表失败 ${e.toString()}');
          }
        }
      } catch (e) {
        debugPrint('初始化WebDav失败 ${e.toString()}');
      }
    }
  }

  _pluginInit() async {
    try {
      pluginsController.queryPluginHTTPList();
      await pluginsController.loadPlugins();
    } catch (_) {}
    if (pluginsController.pluginList.isEmpty) {
      SmartDialog.show(
        animationType: SmartAnimationType.centerFade_otherSlide,
        builder: (context) {
          return AlertDialog(
            title: const Text('插件管理'),
            content: const Text('当前规则数为0, 是否加载示例规则'),
            actions: [
              TextButton(
                onPressed: () {
                  SmartDialog.dismiss();
                  Modular.to.navigate('/tab/popular/');
                },
                child: Text(
                  '取消',
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
                child: const Text('确认'),
              ),
            ],
          );
        },
      );
    } else {
      Modular.to.navigate('/tab/popular/');
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
      debugPrint('当前设备宽屏');
    } else {
      debugPrint('当前设备非宽屏');
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
