import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/mortis.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

class Utils {
  static final Random random = Random();

  static bool? _isDocumentStartScriptSupported;

  /// 检查 Android WebView 是否支持 DOCUMENT_START_SCRIPT 特性
  static Future<void> checkWebViewFeatureSupport() async {
    if (Platform.isAndroid) {
      _isDocumentStartScriptSupported = await PlatformWebViewFeature.static()
          .isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT);
    }
  }

  static bool get isDocumentStartScriptSupported =>
      _isDocumentStartScriptSupported ?? false;

  static Future<bool> isLowResolution() async {
    if (Platform.isMacOS) {
      return false;
    }
    Map<String, double> screenInfo = await getScreenInfo();
    if (screenInfo['height']! / screenInfo['ratio']! < 900) {
      return true;
    }
    return false;
  }

  static String getRandomUA() {
    final random = Random();
    String randomElement =
        userAgentsList[random.nextInt(userAgentsList.length)];
    return randomElement;
  }

  static String getRandomAcceptedLanguage() {
    final random = Random();
    String randomElement =
        acceptLanguageList[random.nextInt(acceptLanguageList.length)];
    return randomElement;
  }

  static Future<Map<String, double>> getScreenInfo() async {
    final MediaQueryData mediaQuery = MediaQueryData.fromView(
        WidgetsBinding.instance.platformDispatcher.views.first);
    final Size screenSize =
        WidgetsBinding.instance.platformDispatcher.displays.first.size;
    final double screenRatio = mediaQuery.devicePixelRatio;
    Map<String, double>? screenInfo = {};
    screenInfo = {
      'width': screenSize.width,
      'height': screenSize.height,
      'ratio': screenRatio
    };
    return screenInfo;
  }

  // 从URL参数中解析 m3u8/mp4
  static String decodeVideoSource(String iframeUrl) {
    var decodedUrl = Uri.decodeFull(iframeUrl);
    RegExp regExp = RegExp(r'(http[s]?://.*?\.m3u8)|(http[s]?://.*?\.mp4)',
        caseSensitive: false);

    Uri uri = Uri.parse(decodedUrl);
    Map<String, String> params = uri.queryParameters;

    String matchedUrl = iframeUrl;
    params.forEach((key, value) {
      if (regExp.hasMatch(value)) {
        matchedUrl = value;
        return;
      }
    });

    return Uri.encodeFull(matchedUrl);
  }

  // 完全相对时间显示
  static String formatTimestampToRelativeTime(timeStamp) {
    var difference = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(timeStamp * 1000));

    if (difference.inDays > 365) {
      return '${difference.inDays ~/ 365}年前';
    } else if (difference.inDays > 30) {
      return '${difference.inDays ~/ 30}个月前';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  // 时间显示，刚刚，x分钟前
  static String dateFormat(timeStamp, {formatType = 'list'}) {
    // 当前时间
    int time = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    // 对比
    int distance = (time - timeStamp).toInt();
    // 当前年日期
    String currentYearStr = 'MM月DD日 hh:mm';
    String lastYearStr = 'YY年MM月DD日 hh:mm';
    if (formatType == 'detail') {
      currentYearStr = 'MM-DD hh:mm';
      lastYearStr = 'YY-MM-DD hh:mm';
      return CustomStamp_str(
          timestamp: timeStamp,
          date: lastYearStr,
          toInt: false,
          formatType: formatType);
    }
    if (distance <= 60) {
      return '刚刚';
    } else if (distance <= 3600) {
      return '${(distance / 60).floor()}分钟前';
    } else if (distance <= 43200) {
      return '${(distance / 60 / 60).floor()}小时前';
    } else if (DateTime.fromMillisecondsSinceEpoch(time * 1000).year ==
        DateTime.fromMillisecondsSinceEpoch(timeStamp * 1000).year) {
      return CustomStamp_str(
          timestamp: timeStamp,
          date: currentYearStr,
          toInt: false,
          formatType: formatType);
    } else {
      return CustomStamp_str(
          timestamp: timeStamp,
          date: lastYearStr,
          toInt: false,
          formatType: formatType);
    }
  }

  // 时间戳转时间
  static String CustomStamp_str(
      {int? timestamp, // 为空则显示当前时间
      String? date, // 显示格式，比如：'YY年MM月DD日 hh:mm:ss'
      bool toInt = true, // 去除0开头
      String? formatType}) {
    timestamp ??= (DateTime.now().millisecondsSinceEpoch / 1000).round();
    String timeStr =
        (DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)).toString();

    dynamic dateArr = timeStr.split(' ')[0];
    dynamic timeArr = timeStr.split(' ')[1];

    String YY = dateArr.split('-')[0];
    String MM = dateArr.split('-')[1];
    String DD = dateArr.split('-')[2];

    String hh = timeArr.split(':')[0];
    String mm = timeArr.split(':')[1];
    String ss = timeArr.split(':')[2];

    ss = ss.split('.')[0];

    // 去除0开头
    if (toInt) {
      MM = (int.parse(MM)).toString();
      DD = (int.parse(DD)).toString();
      hh = (int.parse(hh)).toString();
      mm = (int.parse(mm)).toString();
    }

    if (date == null) {
      return timeStr;
    }

    // if (formatType == 'list' && int.parse(DD) > DateTime.now().day - 2) {
    //   return '昨天';
    // }

    date = date
        .replaceAll('YY', YY)
        .replaceAll('MM', MM)
        .replaceAll('DD', DD)
        .replaceAll('hh', hh)
        .replaceAll('mm', mm)
        .replaceAll('ss', ss);
    if (int.parse(YY) == DateTime.now().year &&
        int.parse(MM) == DateTime.now().month) {
      // 当天
      if (int.parse(DD) == DateTime.now().day) {
        return '今天';
      }
    }
    return date;
  }

  static String makeHeroTag(v) {
    return v.toString() + random.nextInt(9999).toString();
  }

  // 版本对比
  static bool needUpdate(localVersion, remoteVersion) {
    List<String> localVersionList = localVersion.split('.');
    List<String> remoteVersionList = remoteVersion.split('.');
    for (int i = 0; i < localVersionList.length; i++) {
      int localVersion = int.parse(localVersionList[i]);
      int remoteVersion = int.parse(remoteVersionList[i]);
      if (remoteVersion > localVersion) {
        return true;
      } else if (remoteVersion < localVersion) {
        return false;
      }
    }
    return false;
  }

  // 日期字符串转换为 weekday (eg: 2024-09-23 -> 1 (星期一))
  static int dateStringToWeekday(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return date.weekday;
    } catch (_) {
      return 1;
    }
  }

  static String jsonToKazumiBase64(String jsonStr) {
    String base64Str = base64Encode(utf8.encode(jsonStr));
    return 'kazumi://$base64Str';
  }

  static String kazumiBase64ToJson(String kazumiBase64Str) {
    if (!kazumiBase64Str.startsWith('kazumi://')) {
      return '';
    }
    String base64Str = kazumiBase64Str.substring(9);
    String jsonStr = utf8.decode(base64.decode(base64Str));
    return jsonStr;
  }

  static String durationToString(Duration duration) {
    String pad(int n) => n.toString().padLeft(2, '0');
    var hours = pad(duration.inHours % 24);
    var minutes = pad(duration.inMinutes % 60);
    var seconds = pad(duration.inSeconds % 60);
    if (hours == "00") {
      return "$minutes:$seconds";
    } else {
      return "$hours:$minutes:$seconds";
    }
  }

  static Future<String> latest() async {
    try {
      var resp = await Dio().get<Map<String, dynamic>>(Api.latestApp);
      if (resp.data?.containsKey("tag_name") ?? false) {
        return resp.data!["tag_name"];
      } else {
        throw resp.data?["message"];
      }
    } catch (e) {
      return Api.version;
    }
  }

  static oledDarkTheme(ThemeData defaultDarkTheme) {
    return defaultDarkTheme.copyWith(
      scaffoldBackgroundColor: Colors.black,
      colorScheme: defaultDarkTheme.colorScheme.copyWith(
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        // background: Colors.black,
        // onBackground: Colors.black,
        surface: Colors.black,
        onSurface: Colors.white,
      ),
    );
  }

  static generateDanmakuColor(int colorValue) {
    // 提取颜色分量
    int red = (colorValue >> 16) & 0xFF;
    int green = (colorValue >> 8) & 0xFF;
    int blue = colorValue & 0xFF;
    // 创建Color对象
    Color color = Color.fromARGB(255, red, green, blue);
    return color;
  }

  static int extractEpisodeNumber(String input) {
    RegExp regExp = RegExp(r'第?(\d+)[话集]?');
    Match? match = regExp.firstMatch(input);

    if (match != null && match.group(1) != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }

    return 0;
  }

  /// 判断是否为桌面设备
  static bool isDesktop() {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// 判断设备是否为宽屏
  static bool isWideScreen() {
    Box setting = GStorage.setting;
    bool isWideScreen =
        setting.get(SettingBoxKey.isWideScreen, defaultValue: false);
    return isWideScreen;
  }

  /// 判断设备是否为平板
  static bool isTablet() {
    return isWideScreen() && !isDesktop();
  }

  /// 判断设备是否需要紧凑布局
  static bool isCompact() {
    return !isDesktop() && !isWideScreen();
  }

  /// 判断是否分屏模式 (android only)
  static Future<bool> isInMultiWindowMode() async {
    if (Platform.isAndroid) {
      const platform = MethodChannel('com.predidit.kazumi/intent');
      try {
        final bool result =
            await platform.invokeMethod('checkIfInMultiWindowMode');
        return result;
      } on PlatformException catch (e) {
        print("Failed to check multi window mode: '${e.message}'.");
        return false;
      }
    }
    return false;
  }

  // Deprecated
  static Future<void> enterWindowsFullscreen() async {
    if (Platform.isWindows) {
      const platform = MethodChannel('com.predidit.kazumi/intent');
      try {
        await platform.invokeMethod('enterFullscreen');
      } on PlatformException catch (e) {
        print("Failed to enter native window mode: '${e.message}'.");
      }
    }
  }

  // Deprecated
  static Future<void> exitWindowsFullscreen() async {
    if (Platform.isWindows) {
      const platform = MethodChannel('com.predidit.kazumi/intent');
      try {
        await platform.invokeMethod('exitFullscreen');
      } on PlatformException catch (e) {
        print("Failed to exit native window mode: '${e.message}'.");
      }
    }
  }

  // 进入全屏显示
  static Future<void> enterFullScreen({bool lockOrientation = true}) async {
    // if (Platform.isWindows) {
    //   await enterWindowsFullscreen();
    //   return;
    // }
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      await windowManager.setFullScreen(true);
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
    if (!lockOrientation) {
      return;
    }
    if (Platform.isAndroid) {
      bool isInMultiWindowMode = await Utils.isInMultiWindowMode();
      if (isInMultiWindowMode) {
        return;
      }
    }
    await landScape();
  }

  //退出全屏显示
  static Future<void> exitFullScreen({bool lockOrientation = true}) async {
    // if (Platform.isWindows) {
    //   await exitWindowsFullscreen();
    // }
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      await windowManager.setFullScreen(false);
    }
    late SystemUiMode mode = SystemUiMode.edgeToEdge;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        if (Platform.isAndroid &&
            (await DeviceInfoPlugin().androidInfo).version.sdkInt < 29) {
          mode = SystemUiMode.manual;
        }
        await SystemChrome.setEnabledSystemUIMode(
          mode,
          overlays: SystemUiOverlay.values,
        );
        if (Utils.isCompact() && lockOrientation) {
          if (Platform.isAndroid) {
            bool isInMultiWindowMode = await Utils.isInMultiWindowMode();
            if (isInMultiWindowMode) {
              return;
            }
          }
          verticalScreen();
        }
      }
    } catch (exception, stacktrace) {
      KazumiLogger()
          .log(Level.error, exception.toString(), stackTrace: stacktrace);
    }
  }

  //横屏
  static Future<void> landScape() async {
    dynamic document;
    try {
      if (kIsWeb) {
        await document.documentElement?.requestFullscreen();
      } else if (Platform.isAndroid || Platform.isIOS) {
        await SystemChrome.setPreferredOrientations(
          [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
        );
      }
    } catch (exception, stacktrace) {
      KazumiLogger()
          .log(Level.error, exception.toString(), stackTrace: stacktrace);
    }
  }

  //竖屏
  static Future<void> verticalScreen() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  // 解除屏幕旋转限制
  static Future<void> unlockScreenRotation() async {
    await SystemChrome.setPreferredOrientations([]);
  }

  static String getSeasonStringByMonth(int month) {
    if (month <= 3) return '冬';
    if (month <= 6) return '春';
    if (month <= 9) return '夏';
    return '秋';
  }

  // 进入桌面设备小窗模式
  static Future<void> enterDesktopPIPWindow() async {
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSize(const Size(480, 270));
  }

  // 退出桌面设备小窗模式
  static Future<void> exitDesktopPIPWindow() async {
    bool isLowResolution = await Utils.isLowResolution();
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSize(
        isLowResolution ? const Size(800, 600) : const Size(1280, 860));
    await windowManager.center();
  }

  static bool isSameSeason(DateTime d1, DateTime d2) {
    return d1.year == d2.year && (d1.month - d2.month).abs() <= 2;
  }

  static Future<String> getPlayerTempPath() async {
    final directory = await getTemporaryDirectory();
    return directory.path;
  }

  static String buildShadersAbsolutePath(
      String baseDirectory, List<String> shaders) {
    List<String> absolutePaths = shaders.map((shader) {
      return path.join(baseDirectory, shader);
    }).toList();
    if (Platform.isWindows) {
      return absolutePaths.join(';');
    }
    return absolutePaths.join(':');
  }

  static String generateDandanSignature(String path, int timestamp) {
    String id = mortis['id']!;
    String value = mortis['value']!;
    String data = id + timestamp.toString() + path + value;
    var bytes = utf8.encode(data);
    var digest = sha256.convert(bytes);
    return base64Encode(digest.bytes);
  }

  /// 格式化日期
  /// eg: 2025-07-27T09:14:12Z -> 2025-07-27
  static String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  /// 计算文件的 SHA256 哈希值
  static Future<String> calculateFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
