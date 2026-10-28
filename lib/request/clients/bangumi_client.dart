import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/bangumi_acceleration.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/bangumi_mirror_credentials.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/crypto.dart';

class BangumiClient {
  BangumiClient._();

  static final BangumiClient instance = BangumiClient._();

  Future<dynamic> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
    String? accessToken,
    CancelToken? cancelToken,
  }) {
    return _execute(
      method: 'GET',
      url: url,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      accessToken: accessToken,
      cancelToken: cancelToken,
    );
  }

  Future<dynamic> post(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
    CancelToken? cancelToken,
  }) {
    return _execute(
      method: 'POST',
      url: url,
      data: data,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      cancelToken: cancelToken,
    );
  }

  /// 发请求，并在「官方域名连不上」时自动降级到免签名镜像重试一次。
  ///
  /// 背景：`api.bgm.tv` 在部分网络下会直接超时（不是慢，是连不上）。
  /// 以往只有「镜像模式」会被改写到镜像，用户一旦把加速设成直连/ECH，
  /// 主页搜索就会永远 0 条，且界面上只显示「没有找到番剧」，看不出是网络问题。
  Future<dynamic> _execute({
    required String method,
    required String url,
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
    String? accessToken,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _send(
        method: method,
        url: url,
        data: data,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        accessToken: accessToken,
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      final String? fallbackUrl = _fallbackUrlFor(error, url);
      if (fallbackUrl == null) {
        throw await NetworkErrorMapper.mapException(error);
      }
      KazumiLogger().w(
        'BangumiClient: ${Uri.parse(url).host} 不可达，降级到免签名镜像重试',
        error: error,
      );
      try {
        return await _send(
          method: method,
          url: fallbackUrl,
          data: data,
          queryParameters: queryParameters,
          requiresAuth: requiresAuth,
          accessToken: accessToken,
          cancelToken: cancelToken,
        );
      } on DioException catch (retryError) {
        throw await NetworkErrorMapper.mapException(retryError);
      }
    }
  }

  Future<dynamic> _send({
    required String method,
    required String url,
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
    String? accessToken,
    CancelToken? cancelToken,
  }) async {
    final Map<String, dynamic> headers = _headers(
      requiresAuth: requiresAuth,
      accessToken: accessToken,
      url: url,
      method: method,
      data: data,
    );
    final Response<dynamic> response = method == 'GET'
        ? await DioFactory.bangumiDio.get(
            url,
            queryParameters: queryParameters,
            options: Options(headers: headers),
            cancelToken: cancelToken,
          )
        : await DioFactory.bangumiDio.post(
            url,
            data: data,
            queryParameters: queryParameters,
            options: Options(headers: headers),
            cancelToken: cancelToken,
          );
    return response.data;
  }

  /// 只在「网络层根本没连上」时降级；业务错误（4xx/5xx、解析失败）原样抛。
  String? _fallbackUrlFor(DioException error, String url) {
    if (!_isConnectivityFailure(error)) {
      return null;
    }
    // 镜像模式已经被拦截器改到镜像域名了，再降级会打到同一个后端。
    if (BangumiAcceleration.current == BangumiAcceleration.mirror) {
      return null;
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || !ApiEndpoints.bangumiPublicApiHosts.contains(uri.host)) {
      return null;
    }
    // 免签名镜像没有实现 /p1/calendar（实测返回 404，body 为
    // {"request":"/p1/calendar","code":404}）。降级过去只会把「超时」
    // 换成「404」，反而更难判断，这里直接放弃降级。
    if (uri.path == '/p1/calendar') {
      return null;
    }
    final Uri mirror = Uri.parse(ApiEndpoints.bangumiUnsignedMirrorDomain);
    return mirror
        .replace(
          path: uri.path,
          query: uri.hasQuery ? uri.query : null,
        )
        .toString();
  }

  bool _isConnectivityFailure(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        return error.error is SocketException ||
            error.error is HandshakeException;
      case DioExceptionType.transformTimeout:
        return true;
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
        return false;
    }
  }

  Map<String, dynamic> _headers({
    required bool requiresAuth,
    String? accessToken,
    required String url,
    required String method,
    Object? data,
  }) {
    final headers = <String, dynamic>{...bangumiHTTPHeader};
    final bangumiSyncEnable = GStorage.getSetting(
      SettingsKeys.bangumiSyncEnable,
    );
    final token =
        (accessToken ??
                GStorage.getSetting<String>(SettingsKeys.bangumiAccessToken))
            .trim();
    if ((requiresAuth || bangumiSyncEnable) && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (_shouldSignProtectedMirrorRequest(url, method)) {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final body = data == null ? '' : jsonEncode(data);
      headers['X-AppId'] = bangumiMirrorCredentials['id'];
      headers['X-Timestamp'] = timestamp;
      headers['X-Signature'] = generateBangumiMirrorSearchSignature(
        method: method,
        path: Uri.parse(url).path,
        body: body,
        timestamp: timestamp,
      );
    }
    return headers;
  }

  bool _shouldSignProtectedMirrorRequest(String url, String method) {
    // 没有注入凭据时签名必然无效，交给免签名镜像处理，不要发送空的 X-AppId
    if (!hasBangumiMirrorCredentials) {
      return false;
    }
    final uri = Uri.parse(url);
    if (BangumiAcceleration.current != BangumiAcceleration.mirror ||
        !ApiEndpoints.bangumiPublicApiHosts.contains(uri.host)) {
      return false;
    }
    final path = uri.path;
    if (method == 'POST' && path == '/v0/search/subjects') {
      return true;
    }
    if (method != 'GET') {
      return false;
    }
    return path.startsWith('/p1/subjects/') && path.endsWith('/comments') ||
        path.startsWith('/p1/episodes/') && path.endsWith('/comments') ||
        path.startsWith('/p1/characters/') && path.endsWith('/comments');
  }
}
