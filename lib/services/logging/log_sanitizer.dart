class LogSanitizer {
  LogSanitizer._();

  static final RegExp _dataUrlPattern = RegExp(
    r'data:[^;\s]+;base64,[A-Za-z0-9+/=_-]+',
    caseSensitive: false,
  );
  static final RegExp _bearerPattern = RegExp(
    r'\bBearer\s+[^\s,;]+',
    caseSensitive: false,
  );
  static final RegExp _sensitiveAssignmentPattern = RegExp(
    r'\b(authorization|proxy-authorization|cookie|set-cookie|password|passwd|access[_-]?token|refresh[_-]?token)\s*[:=]\s*([^\s,;]+)',
    caseSensitive: false,
  );
  static final RegExp _httpUrlPattern = RegExp(
    r'''https?://[^\s<>"']+''',
    caseSensitive: false,
  );

  /// Removes credentials and private URL components before a value reaches
  /// either the console or the persistent log file.
  static String sanitizeText(String input) {
    var sanitized = input.replaceAll(_dataUrlPattern, 'data:[REDACTED]');
    sanitized = sanitized.replaceAll(_bearerPattern, 'Bearer [REDACTED]');
    sanitized = sanitized.replaceAllMapped(
      _sensitiveAssignmentPattern,
      (match) => '${match.group(1)}=[REDACTED]',
    );
    sanitized = sanitized.replaceAllMapped(
      _httpUrlPattern,
      (match) => sanitizeUri(match.group(0)!),
    );
    return sanitized;
  }

  /// Keeps only the origin needed for diagnostics. Paths can contain account,
  /// media, WebDAV, or rule-specific identifiers, so they are private by
  /// default just like user info, query parameters, and fragments.
  static String sanitizeUri(Object value) {
    final raw = value.toString();
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return sanitizeTextWithoutUris(raw);
    }

    final safeUri = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    );
    return safeUri.toString();
  }

  static String sanitizeTextWithoutUris(String input) {
    var sanitized = input.replaceAll(_dataUrlPattern, 'data:[REDACTED]');
    sanitized = sanitized.replaceAll(_bearerPattern, 'Bearer [REDACTED]');
    return sanitized.replaceAllMapped(
      _sensitiveAssignmentPattern,
      (match) => '${match.group(1)}=[REDACTED]',
    );
  }
}
