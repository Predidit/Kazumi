import 'package:dio/dio.dart';
import 'package:kazumi/request/api.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/mortis.dart';
import 'package:kazumi/utils/constants.dart';

class ApiInterceptor extends Interceptor {
  static Box setting = GStorage.setting;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Github mirror
    if (options.path.contains('github')) {
      bool enableGitProxy =
          setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);
      if (enableGitProxy) {
        options.path = Api.gitMirror + options.path;
      }
    }
    if (options.path.contains(Api.dandanAPIDomain)) {
      var timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      options.headers = {
        'user-agent': Utils.getRandomUA(),
        'referer': '',
        'X-Auth': 1,
        'X-AppId': mortis['id'],
        'X-Timestamp': timestamp,
        'X-Signature': Utils.generateDandanSignature(
            Uri.parse(options.path).path, timestamp),
      };
    }
    if (options.path.contains(Api.bangumiAPIDomain) ||
        options.path.contains(Api.bangumiAPINextDomain)) {
      options.headers = bangumiHTTPHeader;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    String url = err.requestOptions.uri.toString();
    if (!url.contains('heartBeat') &&
        err.requestOptions.extra['customError'] != '') {
      if (err.requestOptions.extra['customError'] == null) {
        KazumiDialog.showToast(
          message: await dioError(err),
        );
      } else {
        KazumiDialog.showToast(
          message: err.requestOptions.extra['customError'],
        );
      }
    }
    super.onError(err, handler);
  }

  static Future<String> dioError(DioException error) async {
    bool proxyEnable =
        await setting.get(SettingBoxKey.proxyEnable, defaultValue: false);
    if (proxyEnable) {
      return '代理连接异常，请检查代理设置';
    }
    switch (error.type) {
      case DioExceptionType.badCertificate:
        return '证书有误！';
      case DioExceptionType.badResponse:
        return '服务器异常，请稍后重试！';
      case DioExceptionType.cancel:
        return '请求已被取消，请重新请求';
      case DioExceptionType.connectionError:
        return '连接错误，请检查网络设置';
      case DioExceptionType.connectionTimeout:
        return '网络连接超时，请检查网络设置';
      case DioExceptionType.receiveTimeout:
        return '响应超时，请稍后重试！';
      case DioExceptionType.sendTimeout:
        return '发送请求超时，请检查网络设置';
      case DioExceptionType.unknown:
        final String res = await checkConnect();
        return '$res 网络异常';
    }
  }

  static Future<String> checkConnect() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.mobile)) {
      return '正在使用移动流量';
    }
    if (connectivityResult.contains(ConnectivityResult.wifi)) {
      return '正在使用wifi';
    }
    if (connectivityResult.contains(ConnectivityResult.ethernet)) {
      return '正在使用局域网';
    }
    if (connectivityResult.contains(ConnectivityResult.vpn)) {
      return '正在使用代理网络';
    }
    if (connectivityResult.contains(ConnectivityResult.other)) {
      return '正在使用其他网络';
    }
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return '未连接到任何网络';
    }
    return '';
  }
}
