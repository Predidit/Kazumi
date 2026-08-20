import 'package:kazumi/request/config/api_endpoints.dart';

class RulesRepositoryConfig {
  const RulesRepositoryConfig._();

  static Uri baseUri(String configuredUrl) {
    final value = configuredUrl.trim();
    if (value.isEmpty) {
      return Uri.parse(ApiEndpoints.pluginShop);
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        !uri.hasAuthority ||
        uri.host.isEmpty) {
      throw const FormatException('规则仓库地址必须是有效的 HTTP 或 HTTPS URL');
    }

    var path = uri.path;
    if (path.endsWith('/index.json')) {
      path = path.substring(0, path.length - 'index.json'.length);
    } else if (!path.endsWith('/')) {
      path = '$path/';
    }

    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: path,
    );
  }

  static String normalizeForStorage(String configuredUrl) {
    if (configuredUrl.trim().isEmpty) {
      return '';
    }
    return baseUri(configuredUrl).toString();
  }

  static Uri catalogUri(String configuredUrl) {
    return baseUri(configuredUrl).resolve('index.json');
  }

  static Uri ruleUri(String configuredUrl, String ruleName) {
    return baseUri(
      configuredUrl,
    ).resolveUri(Uri(pathSegments: ['$ruleName.json']));
  }
}
