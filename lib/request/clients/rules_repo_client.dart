import 'package:dio/dio.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';

class RulesRepoClient {
  RulesRepoClient._();

  static final RulesRepoClient instance = RulesRepoClient._();

  Future<String> getText(String url, {CancelToken? cancelToken}) async {
    try {
      final response = await DioFactory.rulesRepoDio.get<String>(
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
