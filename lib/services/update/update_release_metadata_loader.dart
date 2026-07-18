import 'dart:convert';

typedef UpdateMetadataFetcher = Future<String> Function(String endpoint);
typedef UpdateMetadataFailureObserver = void Function(
  Uri endpoint,
  Object error,
);

/// Loads release metadata in priority order and falls back only after a
/// transport, decoding, or schema failure.
///
/// Keeping the failover outside the UI-facing updater makes the Windows proxy
/// regression testable without making a real network request.
class UpdateReleaseMetadataLoader {
  const UpdateReleaseMetadataLoader({
    required this.endpoints,
    required this.fetch,
    this.onFailure,
  });

  final List<String> endpoints;
  final UpdateMetadataFetcher fetch;
  final UpdateMetadataFailureObserver? onFailure;

  Future<Map<String, dynamic>> load() async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (final endpoint in endpoints) {
      final uri = _validateEndpoint(endpoint);
      try {
        final decoded = json.decode(await fetch(endpoint));
        if (decoded is! Map) {
          throw const FormatException('Update response is not an object');
        }
        final data = Map<String, dynamic>.from(decoded);
        if (data['tag_name'] is! String || data['assets'] is! List) {
          throw const FormatException(
            'Update response is missing release fields',
          );
        }
        return data;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        onFailure?.call(uri, error);
      }
    }

    Error.throwWithStackTrace(
      lastError ?? const FormatException('No update metadata endpoint'),
      lastStackTrace ?? StackTrace.current,
    );
  }

  Uri _validateEndpoint(String endpoint) {
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'Update metadata endpoints must be absolute HTTPS URLs',
      );
    }
    return uri;
  }
}
