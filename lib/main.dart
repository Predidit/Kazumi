import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kazumi/app_module.dart';
import 'package:kazumi/app_widget.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kazumi/request/request.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/pages/error/storage_error_page.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ));
  }

  if (Platform.isAndroid) {
    await Utils.checkWebViewFeatureSupport();
  }

  try {
    await Hive.initFlutter(
        '${(await getApplicationSupportDirectory()).path}/hive');
    await GStorage.init();
  } catch (_) {
    if (Platform.isWindows) {
      await windowManager.ensureInitialized();
      windowManager.waitUntilReadyToShow(null, () async {
        // Native window show has been blocked in `flutter_windows.cppL36` to avoid flickering.
        // Without this. the window will never show on Windows.
        await windowManager.show();
        await windowManager.focus();
      });
    }
    runApp(MaterialApp(
        title: '初始化失败',
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [
          Locale.fromSubtags(
              languageCode: 'zh', scriptCode: 'Hans', countryCode: "CN")
        ],
        locale: const Locale.fromSubtags(
            languageCode: 'zh', scriptCode: 'Hans', countryCode: "CN"),
        builder: (context, child) {
          return const StorageErrorPage();
        }));
    return;
  }
  bool showWindowButton = await GStorage.setting
      .get(SettingBoxKey.showWindowButton, defaultValue: false);
  if (Utils.isDesktop()) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      skipTaskbar: false,
      minimumSize: const Size(320, 270),
      // macOS always hide title bar regardless of showWindowButton setting
      titleBarStyle: (Platform.isMacOS || !showWindowButton)
          ? TitleBarStyle.hidden
          : TitleBarStyle.normal,
      windowButtonVisibility: showWindowButton,
      title: 'Kazumi',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      // Native window show has been blocked in `flutter_windows.cppL36` to avoid flickering.
      // Without this. the window will never show on Windows.
      await windowManager.show();
      Size currentSize = await windowManager.getSize();
      //当第一次启动时或从小窗模式退出后，调整窗口到合适大小
      if (Modular.get<PluginsController>().pluginList.isEmpty || currentSize == Size(480, 270)) {
        bool isLowResolution = await Utils.isLowResolution();
        await windowManager.setSize(
            isLowResolution ? const Size(800, 600) : const Size(1280, 860));
        await windowManager.center();
      }
      await windowManager.focus();
    });
  }
  Request();
  await Request.setCookie();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: ModularApp(
        module: AppModule(),
        child: const AppWidget(),
      ),
    ),
  );
}
