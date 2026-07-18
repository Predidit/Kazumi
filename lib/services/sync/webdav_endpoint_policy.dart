class WebDavEndpointPolicyException implements FormatException {
  const WebDavEndpointPolicyException(this.message);

  @override
  final String message;

  @override
  int? get offset => null;

  @override
  dynamic get source => null;

  @override
  String toString() => 'WebDavEndpointPolicyException: $message';
}

/// Validates the user-configured WebDAV base address before credentials are
/// handed to the client. Plain HTTP remains supported for existing local/LAN
/// servers; TLS policy is otherwise left to the platform client.
String validateWebDavEndpoint(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || _containsControlCharacter(trimmed)) {
    throw const WebDavEndpointPolicyException(
      'WebDAV URL cannot be empty or contain control characters',
    );
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      (uri.scheme.toLowerCase() != 'http' &&
          uri.scheme.toLowerCase() != 'https') ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const WebDavEndpointPolicyException(
      'WebDAV URL must be an absolute HTTP(S) URL without embedded credentials',
    );
  }
  return trimmed;
}

bool _containsControlCharacter(String value) {
  return value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f);
}
