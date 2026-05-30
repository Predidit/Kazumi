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
          message: 'Certificate error!',
          rawError: error,
          stackTrace: error.stackTrace,
        );
      case DioExceptionType.badResponse:
        return NetworkException(
          type: NetworkExceptionType.badResponse,
          message: 'Server error, please try again later!',
          statusCode: error.response?.statusCode,
          rawError: error,
          stackTrace: error.stackTrace,
        );
      case DioExceptionType.cancel:
        return NetworkException(
          type: NetworkExceptionType.cancel,
          message: 'Request canceled, please try again',
          rawError: error,
          stackTrace: error.stackTrace,
        );
      case DioExceptionType.connectionError:
        return NetworkException(
          type: NetworkExceptionType.connectionError,
          message: 'Connection error, please check your network settings',
          rawError: error,
          stackTrace: error.stackTrace,
        );
      case DioExceptionType.connectionTimeout:
        return NetworkException(
          type: NetworkExceptionType.connectionTimeout,
          message: 'Network connection timed out, please check your network settings',
          rawError: error,
          stackTrace: error.stackTrace,
        );
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          type: NetworkExceptionType.receiveTimeout,
          message: 'Response timed out, please try again later!',
          rawError: error,
          stackTrace: error.stackTrace,
        );
      case DioExceptionType.sendTimeout:
        return NetworkException(
          type: NetworkExceptionType.sendTimeout,
          message: 'Request send timed out, please check your network settings',
          rawError: error,
          stackTrace: error.stackTrace,
        );
      case DioExceptionType.unknown:
        final connection = await _connectionLabel();
        return NetworkException(
          type: NetworkExceptionType.unknown,
          message: '$connection network error'.trimLeft(),
          rawError: error,
          stackTrace: error.stackTrace,
        );
    }
  }

  static NetworkException parse(Object error, StackTrace stackTrace) {
    return NetworkException(
      type: NetworkExceptionType.parseError,
      message: 'Failed to parse response',
      rawError: error,
      stackTrace: stackTrace,
    );
  }

  static Future<String> _connectionLabel() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.mobile)) {
      return 'Using mobile data';
    }
    if (connectivityResult.contains(ConnectivityResult.wifi)) {
      return 'Using Wi-Fi';
    }
    if (connectivityResult.contains(ConnectivityResult.ethernet)) {
      return 'Using LAN';
    }
    if (connectivityResult.contains(ConnectivityResult.vpn)) {
      return 'Using proxy network';
    }
    if (connectivityResult.contains(ConnectivityResult.other)) {
      return 'Using another network';
    }
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return 'Not connected to any network';
    }
    return '';
  }
}
