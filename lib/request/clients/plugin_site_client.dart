import 'package:dio/dio.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';
import 'package:kazumi/utils/utils.dart';

class PluginSiteClient {
  PluginSiteClient._();

  static final PluginSiteClient instance = PluginSiteClient._();

  Future<String> getText(
    String url, {
    Map<String, dynamic> headers = const {},
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await DioFactory.pluginDio.get<String>(
        url,
        options: Options(
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

  Future<String> postFormText(
    String url, {
    Object? data,
    Map<String, dynamic> headers = const {},
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await DioFactory.pluginDio.post<String>(
        url,
        data: data,
        options: Options(
          responseType: ResponseType.plain,
          headers: _headers({
            'Content-Type': 'application/x-www-form-urlencoded',
            ...headers,
          }),
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
      'user-agent': Utils.getRandomUA(),
      'Accept-Language': Utils.getRandomAcceptedLanguage(),
      'Connection': 'keep-alive',
      ...headers,
    };
  }
}
