import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kazumi/app_module.dart';
import 'package:kazumi/app_widget.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kazumi/request/request.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 850),
      center: true,
      // backgroundColor: Colors.white,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  MediaKit.ensureInitialized();
  await Hive.initFlutter('${(await getApplicationSupportDirectory()).path}/hive');
  await GStorage.init();
  Request();
  await Request.setCookie();
  runApp(ModularApp(
    module: AppModule(),
    child: const AppWidget(),
  ));
}
