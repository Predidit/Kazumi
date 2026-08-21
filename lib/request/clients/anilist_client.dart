import 'package:dio/dio.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';

class AniListClient {
  AniListClient._();

  static final AniListClient instance = AniListClient._();

  Future<dynamic> query(
    String query, {
    Map<String, dynamic> variables = const {},
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await DioFactory.apiDio.post(
        ApiEndpoints.aniListAPIDomain,
        data: {
          'query': query,
          'variables': variables,
        },
        options: Options(
          headers: const {'content-type': 'application/json'},
        ),
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }
}
