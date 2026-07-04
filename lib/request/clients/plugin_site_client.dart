import 'package:dio/dio.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';
import 'package:kazumi/utils/http_headers.dart';

class PluginSiteClient {
  PluginSiteClient._();

  static final PluginSiteClient instance = PluginSiteClient._();

  Future<String> getText(
    String url, {
    Map<String, dynamic> headers = const {},
    CancelToken? cancelToken,
  }) async {
    return requestText(
      url,
      method: 'GET',
      headers: headers,
      cancelToken: cancelToken,
    );
  }

  Future<String> postFormText(
    String url, {
    Object? data,
    Map<String, dynamic> headers = const {},
    CancelToken? cancelToken,
  }) async {
    return requestText(
      url,
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        ...headers,
      },
      data: data,
      cancelToken: cancelToken,
    );
  }

  Future<String> requestText(
    String url, {
    required String method,
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? data,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await DioFactory.pluginDio.request<String>(
        url,
        queryParameters: queryParameters,
        data: data,
        options: Options(
          method: method,
          responseType: ResponseType.plain,
          headers: _headers(headers),
        ),
        cancelToken: cancelToken,
      );
      return response.data ?? '';
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  Map<String, dynamic> _headers(Map<String, dynamic> headers) {
    return {
      'user-agent': getRandomUA(),
      'Accept-Language': getRandomAcceptedLanguage(),
      'Connection': 'keep-alive',
      ...headers,
    };
  }
}
