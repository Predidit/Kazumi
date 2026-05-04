import 'package:dio/dio.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';

class GithubClient {
  GithubClient._();

  static final GithubClient instance = GithubClient._();

  Future<Map<String, dynamic>> latestRelease() async {
    final data = await getJson(ApiEndpoints.latestApp);
    return Map<String, dynamic>.from(data);
  }

  Future<String> latestVersion() async {
    final data = await latestRelease();
    return data['tag_name']?.toString() ?? ApiEndpoints.version;
  }

  Future<dynamic> getJson(
    String url, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await DioFactory.githubDio.get(
        url,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  Future<String> getText(String url, {CancelToken? cancelToken}) async {
    try {
      final response = await DioFactory.githubDio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
        cancelToken: cancelToken,
      );
      return response.data ?? '';
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }
}
