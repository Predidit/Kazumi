class RuleRequestPolicyException implements Exception {
  const RuleRequestPolicyException(this.message);

  final String message;

  @override
  String toString() => 'RuleRequestPolicyException: $message';
}

class RuleRequestPolicy {
  RuleRequestPolicy._();

  static const int _maximumUrlLength = 16 * 1024;
  static const int _maximumHeaderCount = 100;
  static const int _maximumHeaderValueLength = 16 * 1024;
  static final RegExp _headerName = RegExp(
    r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$",
  );

  static Uri validateHttpUrl(String value) {
    if (value.isEmpty || value.length > _maximumUrlLength) {
      throw const RuleRequestPolicyException(
        'Rule request URL is empty or too long',
      );
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme.toLowerCase() != 'http' &&
            uri.scheme.toLowerCase() != 'https') ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const RuleRequestPolicyException(
        'Rule requests must use an absolute HTTP or HTTPS URL without '
        'embedded credentials',
      );
    }
    return uri;
  }

  static void validateHeaders(Map<String, dynamic> headers) {
    if (headers.length > _maximumHeaderCount) {
      throw const RuleRequestPolicyException(
        'Rule request contains too many headers',
      );
    }
    for (final entry in headers.entries) {
      if (entry.key.isEmpty ||
          entry.key.length > 256 ||
          !_headerName.hasMatch(entry.key)) {
        throw const RuleRequestPolicyException(
          'Rule request contains an invalid header name',
        );
      }
      final values = entry.value is Iterable
          ? (entry.value as Iterable).map((value) => value.toString())
          : <String>[entry.value.toString()];
      for (final value in values) {
        if (value.length > _maximumHeaderValueLength ||
            value.contains('\r') ||
            value.contains('\n') ||
            value.contains('\u0000')) {
          throw const RuleRequestPolicyException(
            'Rule request contains an invalid header value',
          );
        }
      }
    }
  }
}
