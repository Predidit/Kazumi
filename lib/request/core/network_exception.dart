enum NetworkExceptionType {
  badCertificate,
  badResponse,
  cancel,
  connectionError,
  connectionTimeout,
  receiveTimeout,
  sendTimeout,
  unsupportedMirroredEndpoint,
  parseError,
  unknown,
}

class NetworkException implements Exception {
  final NetworkExceptionType type;
  final String message;
  final int? statusCode;
  final Object? rawError;
  final StackTrace? stackTrace;

  const NetworkException({
    required this.type,
    required this.message,
    this.statusCode,
    this.rawError,
    this.stackTrace,
  });

  @override
  String toString() {
    if (type == NetworkExceptionType.unsupportedMirroredEndpoint) {
      return message;
    }
    final status = statusCode == null ? '' : ' ($statusCode)';
    return 'NetworkException.$type$status: $message';
  }
}
