import 'package:kazumi/request/config/api_endpoints.dart';

class RulesRepositoryConfig {
  const RulesRepositoryConfig._();

  static String normalizeForStorage(String input) {
    if (input.trim().isEmpty) {
      return '';
    }
    final normalized = _baseUri(input).toString();
    return normalized == ApiEndpoints.pluginShop ? '' : normalized;
  }

  static Uri catalogUri(String repository) {
    return _baseUri(repository).resolve('index.json');
  }

  static Uri ruleUri(String repository, String ruleName) {
    return _baseUri(
      repository,
    ).resolveUri(Uri(pathSegments: ['$ruleName.json']));
  }

  static Uri _baseUri(String repository) {
    final value = repository.trim();
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
    if (uri.host == 'github.com') {
      throw const FormatException('请使用 raw 文件地址，不要使用 GitHub 仓库网页地址');
    }

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final last = segments.isEmpty ? null : segments.last;
    if (last?.toLowerCase() == 'index.json') {
      segments.removeLast();
    } else if (last != null && last.contains('.') && !uri.path.endsWith('/')) {
      throw const FormatException('规则仓库地址必须是目录或以 index.json 结尾');
    }

    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      pathSegments: [...segments, ''],
    );
  }
}
