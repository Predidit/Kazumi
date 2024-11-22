import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/request/api.dart';
import 'package:screen_pixel/screen_pixel.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:logger/logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

class Utils {
  static final Random random = Random();

  static Future<bool> isLowResolution() async {
    if (Platform.isMacOS) {
      return false;
    }

    try {
      Map<String, double>? screenInfo = await getScreenInfo();
      if (screenInfo != null) {
        if (screenInfo['height']! / screenInfo['ratio']! < 900) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static String getRandomUA() {
    final random = Random();
    String randomElement =
        userAgentsList[random.nextInt(userAgentsList.length)];
    return randomElement;
  }

  static Future<Map<String, double>?> getScreenInfo() async {
    final screenPixelPlugin = ScreenPixel();
    Map<String, double>? screenResolution;
    final MediaQueryData mediaQuery = MediaQueryData.fromView(
        WidgetsBinding.instance.platformDispatcher.views.first);
    final double screenRatio = mediaQuery.devicePixelRatio;
    Map<String, double>? screenInfo = {};

    try {
      screenResolution = await screenPixelPlugin.getResolution();
      screenInfo = {
        'width': screenResolution['width']!,
        'height': screenResolution['height']!,
        'ratio': screenRatio
      };
    } on PlatformException {
      screenInfo = null;
    }
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
    List<String> remoteVersionList = remoteVersion.split('v')[1].split('.');
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

  static String richTextParser(String input) {
    RegExp bgmEmoji = RegExp(r'\(bgm(\d+)\)');
    input = input.replaceAllMapped(bgmEmoji, (match) {
      if (match.group(1) == '11' || match.group(1) == '23') {
        return '<image>https://bangumi.tv/img/smiles/bgm/${match.group(1)}.gif</image>';
      }
      int num = int.tryParse(match.group(1)!) ?? 0;
      if (num < 24) {
        return '<image>https://bangumi.tv/img/smiles/bgm/${match.group(1)}.png</image>';
      }
      if (num < 33) {
        return '<image>https://bangumi.tv/img/smiles/tv/0${num - 23}.gif</image>';
      }
      return '<image>https://bangumi.tv/img/smiles/tv/${num - 23}.gif</image>';
    });

    RegExp quote = RegExp(r'\[quote\]([\s\S]*?)\[/quote\]');
    input = input.replaceAllMapped(quote, (match) {
      return '<q>${match.group(1)}</q><format_quote/>';
    });

    RegExp bold = RegExp(r'\[b\]([\s\S]*?)\[/b\]');
    input = input.replaceAllMapped(bold, (match) {
      return '<b>${match.group(1)}</b>';
    });

    RegExp img = RegExp(r'\[img([\s\S]*?)\]([\s\S]*?)\[/img\]');
    input = input.replaceAllMapped(img, (match) {
      return '<image>${match.group(2)}</image>';
    });

    RegExp strikeThrough = RegExp(r'\[s\]([\s\S]*?)\[/s\]');
    input = input.replaceAllMapped(strikeThrough, (match) {
      return '<s>${match.group(1)}</s>';
    });

    RegExp underLine = RegExp(r'\[u\]([\s\S]*?)\[/u\]');
    input = input.replaceAllMapped(underLine, (match) {
      return '<u>${match.group(1)}</u>';
    });

    RegExp italic = RegExp(r'\[i\]([\s\S]*?)\[/i\]');
    input = input.replaceAllMapped(italic, (match) {
      return '<i>${match.group(1)}</i>';
    });

    RegExp ignore = RegExp(r'\[(mask|code)\]([\s\S]*?)\[/\1\]');
    input = input.replaceAllMapped(ignore, (match) {
      return '${match.group(2)}';
    });

    RegExp link = RegExp(r'\[url=([\s\S]*?)\]([\s\S]*?)\[/url\]');
    input = input.replaceAllMapped(link, (match) {
      return '<link href="${match.group(1)}">${match.group(2)}</link>';
    });

    RegExp color = RegExp(r'\[color=([\s\S]*?)\]([\s\S]*?)\[/color\]');
    input = input.replaceAllMapped(color, (match) {
      return '<color color="${match.group(1)}">${match.group(2)}</color>';
    });

    RegExp size = RegExp(r'\[size=(\d+)\]([\s\S]*?)\[/size\]');
    input = input.replaceAllMapped(size, (match) {
      return '<size size="${match.group(1)}">${match.group(2)}</size>';
    });

    // 为了解决一些特殊情况再执行一次
    RegExp secondColor = RegExp(r'\[color=([\s\S]*?)\]([\s\S]*?)\[/color\]');
    input = input.replaceAllMapped(secondColor, (match) {
      return '<color color="${match.group(1)}">${match.group(2)}</color>';
    });

    return input;
  }

  /// 判断是否为桌面设备
  static bool isDesktop() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return true;
    }
    return false;
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
    if (Platform.isWindows) {
      await enterWindowsFullscreen();
      return;
    }
    if (Platform.isLinux || Platform.isMacOS) {
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
    if (Platform.isWindows) {
      await exitWindowsFullscreen();
    }
    if (Platform.isLinux || Platform.isMacOS) {
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

  // 获取当前解复用器
  static Future<String> getCurrentDemux() async {
    Box setting = GStorage.setting;
    bool haEnable =
        await setting.get(SettingBoxKey.hAenable, defaultValue: true);
    if (Platform.isIOS && haEnable) {
      return 'AVPlayer';
    }
    if (Platform.isMacOS && haEnable) {
      return 'VT';
    }
    if (Platform.isAndroid && haEnable) {
      return 'ExoPlayer';
    }
    return 'FFmpeg';
  }
}
