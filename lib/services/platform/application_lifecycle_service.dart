import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/sync/webdav.dart';

/// Flushes bounded, user-visible state before a desktop process exits.
class ApplicationLifecycleService {
  ApplicationLifecycleService._();

  static const exitFlushTimeout = Duration(seconds: 5);

  static Future<void> flushBeforeExit() async {
    try {
      await WebDav().flushScheduledHistorySync().timeout(exitFlushTimeout);
    } catch (error, stackTrace) {
      // Exiting must remain possible while an offline WebDAV server is
      // unavailable. The durable local history event log remains available to
      // the next startup; only the bounded final upload attempt failed.
      KazumiLogger().w(
        'Application: pending history sync could not finish before exit',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
