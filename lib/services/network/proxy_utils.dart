/// Utilities for validating and normalizing the user-configured HTTP proxy.
class ProxyUtils {
  ProxyUtils._();

  /// Parses the supported `host:port` and `http(s)://host:port` forms.
  static (String, int)? parseProxyUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || _containsControlCharacter(trimmed)) return null;

    final candidate = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        (uri.scheme.toLowerCase() != 'http' &&
            uri.scheme.toLowerCase() != 'https') ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !uri.hasPort ||
        uri.port < 1 ||
        uri.port > 65535 ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }

    return (uri.host, uri.port);
  }

  /// Returns the HTTP proxy form expected by MediaKit and WebView.
  static String? getFormattedProxyUrl(String url) {
    final parsed = parseProxyUrl(url);
    if (parsed == null) return null;
    final host = parsed.$1.contains(':') ? '[${parsed.$1}]' : parsed.$1;
    return 'http://$host:${parsed.$2}';
  }

  static bool isValidProxyUrl(String url) {
    return parseProxyUrl(url) != null;
  }

  static bool _containsControlCharacter(String value) {
    return value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f);
  }
}
