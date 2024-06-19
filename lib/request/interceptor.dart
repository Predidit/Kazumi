import 'package:dio/dio.dart';
import 'package:kazumi/request/api.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ApiInterceptor extends Interceptor {
  static Box setting = GStorage.setting;
  bool enableGitProxy = setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Github mirror
    if (options.path.contains('github') && enableGitProxy) {
      options.path = Api.gitMirror + options.path;
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
    if (!url.contains('heartBeat')) {
      SmartDialog.showToast(
        await dioError(err),
        displayType: SmartToastType.onlyRefresh,
      );
    }
    super.onError(err, handler);
    // super.onError(err, handler);
  }

  static Future<String> dioError(DioException error) async {
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
    final ConnectivityResult connectivityResult =
        await Connectivity().checkConnectivity();
    switch (connectivityResult) {
      case ConnectivityResult.mobile:
        return '正在使用移动流量';
      case ConnectivityResult.wifi:
        return '正在使用wifi';
      case ConnectivityResult.ethernet:
        return '正在使用局域网';
      case ConnectivityResult.vpn:
        return '正在使用代理网络';
      case ConnectivityResult.other:
        return '正在使用其他网络';
      case ConnectivityResult.none:
        return '未连接到任何网络';
      default:
        return '';
    }
  }
}
