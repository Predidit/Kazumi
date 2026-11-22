import 'package:dio/dio.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/ech_adapter.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';
import 'package:kazumi/services/network/rules_mirror.dart';

class RulesRepoClient {
  RulesRepoClient._();

  static final RulesRepoClient instance = RulesRepoClient._();

  Future<String> getText(String url, {CancelToken? cancelToken}) async {
    final mirror = url.startsWith(ApiEndpoints.pluginShop)
        ? RulesMirror.current
        : RulesMirror.direct;
    try {
      final response = await DioFactory.rulesRepoDio.get<String>(
        switch (mirror) {
          RulesMirror.direct => url,
          RulesMirror.ghProxy => ApiEndpoints.ghProxyMirror + url,
          RulesMirror.ghfast => ApiEndpoints.ghfastMirror + url,
          RulesMirror.gitcode =>
            ApiEndpoints.gitcodeMirror +
                url.substring(ApiEndpoints.pluginShop.length),
        },
        options: Options(
          responseType: ResponseType.plain,
          extra: mirror == RulesMirror.ghProxy ? echExtra : null,
        ),
        cancelToken: cancelToken,
      );
      return response.data ?? '';
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }
}
