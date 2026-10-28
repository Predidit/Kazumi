import 'package:dio/dio.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/core/ech_adapter.dart';
import 'package:kazumi/services/network/bangumi_acceleration.dart';
import 'package:kazumi/services/network/rules_mirror.dart';
import 'package:kazumi/utils/bangumi_mirror_credentials.dart';

class BangumiAccelerationInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final uri = options.uri;
    if (ApiEndpoints.bangumiPublicApiHosts.contains(uri.host)) {
      // 未注入签名凭据时镜像必然拒绝请求（401），退回免签名镜像保证可用
      final String mirrorBase = hasBangumiMirrorCredentials
          ? ApiEndpoints.bangumiMirrorDomain
          : ApiEndpoints.bangumiUnsignedMirrorDomain;
      switch (BangumiAcceleration.current) {
        case BangumiAcceleration.direct:
          break;
        case BangumiAcceleration.ech:
          options.path = uri.replace(scheme: 'https').toString();
          options.queryParameters = {};
          options.requireEch();
        case BangumiAcceleration.mirror:
          options.path =
              mirrorBase + uri.path + (uri.hasQuery ? '?${uri.query}' : '');
          options.queryParameters = {};
      }
    }
    handler.next(options);
  }
}

class RulesMirrorInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final url = options.uri.toString();
    if (url.startsWith(ApiEndpoints.pluginShop)) {
      switch (RulesMirror.current) {
        case RulesMirror.direct:
          break;
        case RulesMirror.ghProxy:
          options.path = ApiEndpoints.ghProxyMirror + url;
          options.requireEch();
        case RulesMirror.ghfast:
          options.path = ApiEndpoints.ghfastMirror + url;
        case RulesMirror.gitcode:
          options.path =
              ApiEndpoints.gitcodeMirror +
              url.substring(ApiEndpoints.pluginShop.length);
      }
    }
    handler.next(options);
  }
}
