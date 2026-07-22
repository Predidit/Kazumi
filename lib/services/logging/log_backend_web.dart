import 'package:flutter/foundation.dart';
import 'package:kazumi/services/logging/log_sanitizer.dart';

class KazumiLogBackend {
  KazumiLogBackend._();

  static void writeConsole(String line) {
    debugPrint(LogSanitizer.sanitizeText(line));
  }

  static void writePersistent(Iterable<String> lines) {
    // Browser logs remain in the developer console. Persisting log files would
    // require a user-authorized download and must not happen implicitly.
  }

  static Future<dynamic> getLogsPath() {
    throw UnsupportedError('Persistent log files are unavailable on Web');
  }

  static Future<bool> clearLogs() async => true;
}
