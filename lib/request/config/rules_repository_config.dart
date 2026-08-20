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
    if (uri.userInfo.isNotEmpty) {
      throw const FormatException('规则仓库地址不能包含用户名或密码');
    }
    if (uri.hasQuery || uri.hasFragment) {
      throw const FormatException('规则仓库地址不能包含查询参数或片段');
    }

    final pathSegments =
        uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    final lastSegment = pathSegments.isEmpty ? null : pathSegments.last;
    late final List<String> directorySegments;
    if (lastSegment?.toLowerCase() == 'index.json') {
      directorySegments = pathSegments.sublist(0, pathSegments.length - 1);
    } else {
      if (lastSegment != null &&
          lastSegment.contains('.') &&
          !uri.path.endsWith('/')) {
        throw const FormatException('规则仓库地址必须是目录或以 index.json 结尾');
      }
      if (uri.host.toLowerCase() == 'github.com') {
        throw const FormatException('请使用 raw 文件地址，不要使用 GitHub 仓库网页地址');
      }
      directorySegments = pathSegments;
    }

    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      pathSegments: [...directorySegments, ''],
    );
  }

  static String normalizeForStorage(String configuredUrl) {
    if (configuredUrl.trim().isEmpty) {
      return '';
    }
    final normalized = baseUri(configuredUrl).toString();
    return normalized.startsWith(ApiEndpoints.pluginShop) ? '' : normalized;
  }

  static bool isCustomRepository(String configuredUrl) {
    final value = configuredUrl.trim();
    if (value.isEmpty) return false;
    try {
      return !baseUri(value).toString().startsWith(ApiEndpoints.pluginShop);
    } on FormatException {
      return true;
    }
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
