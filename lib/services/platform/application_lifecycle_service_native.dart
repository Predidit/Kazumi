import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/sync/webdav.dart';

class ApplicationLifecycleService {
  ApplicationLifecycleService._();

  static const exitFlushTimeout = Duration(seconds: 5);

  static Future<void> flushBeforeExit() async {
    try {
      await WebDav().flushScheduledHistorySync().timeout(exitFlushTimeout);
    } catch (error, stackTrace) {
      KazumiLogger().w(
        'Application: pending history sync could not finish before exit',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
