import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

class KazumiLogger {
  KazumiLogger._internal();
  static final KazumiLogger _instance = KazumiLogger._internal();
  factory KazumiLogger() {
    return _instance;
  }

  final Logger _logger = Logger();

  /// Global lock to ensure file writing is executed synchronously
  static final Lock _logLock = Lock();

  Future<void> _writeToFile(Level level, dynamic message,
      {Object? error, StackTrace? stackTrace}) async {
    try {
      String dir = (await getApplicationSupportDirectory()).path;
      final String logDir = p.join(dir, "logs");
      final String filename = p.join(logDir, "kazumi_logs.log");

      final directory = Directory(logDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final timestamp = DateTime.now().toString();
      final levelName = level.name.toUpperCase();
      final errorInfo = error != null ? '\nError: $error' : '';
      final stackInfo = stackTrace != null ? '\nStackTrace:\n$stackTrace' : '';

      await _logLock.synchronized(() async {
        await File(filename).writeAsString(
          '[$timestamp] [$levelName] $message$errorInfo$stackInfo\n\n',
          mode: FileMode.writeOnlyAppend,
        );
      });
    } catch (e) {
      print('Failed to write log to file: $e');
    }
  }

  /// Trace log - lowest level, very detailed information
  void t(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// Debug log - detailed information for debugging
  void d(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Info log - informational messages
  void i(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Warning log - potentially harmful situations
  void w(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    _writeToFile(Level.warning, message, error: error, stackTrace: stackTrace);
  }

  /// Error log - error events that might still allow the app to continue
  void e(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _writeToFile(Level.error, message, error: error, stackTrace: stackTrace);
  }

  /// Fatal log - very severe error events that will presumably lead the app to abort
  void f(dynamic message, {Object? error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
    _writeToFile(Level.fatal, message, error: error, stackTrace: stackTrace);
  }
}

Future<File> getLogsPath() async {
  String dir = (await getApplicationSupportDirectory()).path;
  final String logDir = p.join(dir, "logs");
  final String filename = p.join(logDir, "kazumi_logs.log");

  final directory = Directory(logDir);
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final file = File(filename);
  if (!await file.exists()) {
    await KazumiLogger._logLock.synchronized(() async {
      if (!await file.exists()) {
        await file.create();
      }
    });
  }
  return file;
}

Future<bool> clearLogs() async {
  String dir = (await getApplicationSupportDirectory()).path;
  final String logDir = p.join(dir, "logs");
  final String filename = p.join(logDir, "kazumi_logs.log");

  final directory = Directory(logDir);
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final file = File(filename);
  try {
    await KazumiLogger._logLock.synchronized(() async {
      await file.writeAsString('');
    });
  } catch (e) {
    print('Error clearing file: $e');
    return false;
  }
  return true;
}
