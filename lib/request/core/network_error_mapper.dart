import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:kazumi/request/core/network_exception.dart';

class NetworkErrorMapper {
  const NetworkErrorMapper._();

  static Future<NetworkException> mapException(DioException error) async {
    switch (error.type) {
      case DioExceptionType.badCertificate:
        return NetworkException(
          type: NetworkExceptionType.badCertificate,
          message: '证书有误！',
          rawError: error,
          stackTrace: error.stackTrace,
        );
      case DioExceptionType.badResponse:
        return NetworkException(
          type: NetworkExceptionType.badResponse,
          message: '服务器异常，请稍后重试！',
          statusCode: error.response?.statusCode,
          rawError: error,
          stackTrace: error.stackTrace,
        );
      case DioExceptionType.cancel:
        return NetworkException(
          type: NetworkExceptionType.cancel,
          message: '请求已被取消，请重新请求',
          rawError: error,
          stackTrace: error.stackTrace,
        );
      case DioExceptionType.connectionError:
        return NetworkException(
          type: NetworkExceptionType.connectionError,
          message: '连接错误，请检查网络设置',
          rawError: error,
          stackTrace: error.stackTrace,
        );
      case DioExceptionType.connectionTimeout:
        return NetworkException(
          type: NetworkExceptionType.connectionTimeout,
          message: '网络连接超时，请检查网络设置',
          rawError: error,
          stackTrace: error.stackTrace,
        );
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          type: NetworkExceptionType.receiveTimeout,
          message: '响应超时，请稍后重试！',
          rawError: error,
          stackTrace: error.stackTrace,
        );
      case DioExceptionType.sendTimeout:
        return NetworkException(
          type: NetworkExceptionType.sendTimeout,
          message: '发送请求超时，请检查网络设置',
          rawError: error,
          stackTrace: error.stackTrace,
        );
      case DioExceptionType.unknown:
        final connection = await _connectionLabel();
        return NetworkException(
          type: NetworkExceptionType.unknown,
          message: '$connection 网络异常'.trimLeft(),
          rawError: error,
          stackTrace: error.stackTrace,
        );
    }
  }

  static NetworkException parse(Object error, StackTrace stackTrace) {
    return NetworkException(
      type: NetworkExceptionType.parseError,
      message: '响应解析失败',
      rawError: error,
      stackTrace: stackTrace,
    );
  }

  static Future<String> _connectionLabel() async {
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
