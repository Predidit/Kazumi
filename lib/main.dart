import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kazumi/app_module.dart';
import 'package:kazumi/app_widget.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:kazumi/services/network/proxy_manager.dart';
import 'package:kazumi/services/network/system_proxy_service.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/pages/error/storage_error_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/services/platform/webview_feature_service.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/services/logging/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  KazumiLogger.enablePersistentLogging();
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
    await WebViewFeatureService.initialize();
  }

  try {
    final hivePath = '${(await getApplicationSupportDirectory()).path}/hive';
    await Hive.initFlutter(hivePath);
    await GStorage.init();
  } catch (e) {
    // Log the error for debugging (if logger is available)
    debugPrint('Storage initialization failed: $e');

    if (isDesktop()) {
      await windowManager.ensureInitialized();
      windowManager.waitUntilReadyToShow(null, () async {
        // window_manager controls desktop visibility to avoid startup flicker.
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
  bool showWindowButton =
      await GStorage.getSetting(SettingsKeys.showWindowButton);
  if (isDesktop()) {
    await windowManager.ensureInitialized();
    final lowResolution = await isLowResolution();
    WindowOptions windowOptions = WindowOptions(
      size: lowResolution ? const Size(840, 600) : const Size(1280, 860),
      center: true,
      skipTaskbar: false,
      // macOS always hide title bar regardless of showWindowButton setting
      titleBarStyle: (Platform.isMacOS || !showWindowButton)
          ? TitleBarStyle.hidden
          : TitleBarStyle.normal,
      windowButtonVisibility: showWindowButton,
      title: 'Kazumi',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      // window_manager controls desktop visibility to avoid startup flicker.
      await windowManager.show();
      await windowManager.focus();
    });
  }
  if (Platform.isWindows) {
    SystemProxyService.init();
  }
  ProxyManager.applyProxy();
  runApp(
    ModularApp(
      module: appModule,
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [KazumiDialog.observer],
      defaultTransition: TransitionType.material,
      provide: (scoped) {
        scoped.addChangeNotifier<ThemeProvider>(ThemeProvider.new);
      },
      child: const AppWidget(),
    ),
  );
}
