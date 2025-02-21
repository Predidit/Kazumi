import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

class KazumiLogger extends Logger {
  KazumiLogger._internal() : super();
  static final KazumiLogger _instance = KazumiLogger._internal();
  factory KazumiLogger() {
    return _instance;
  }

  /// Global lock to ensure file writing is executed synchronously
  static final Lock _logLock = Lock();

  @override
  void log(Level level, dynamic message,
      {Object? error, StackTrace? stackTrace, DateTime? time}) async {
    if (level == Level.error) {
      String dir = (await getApplicationSupportDirectory()).path;
      final String logDir = p.join(dir, "logs");
      final String filename = p.join(logDir, "kazumi_logs.log");

      final directory = Directory(logDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      await _logLock.synchronized(() async {
        await File(filename).writeAsString(
          "**${DateTime.now()}** \n$message \n${stackTrace == null ? '' : stackTrace.toString()} \n",
          mode: FileMode.writeOnlyAppend,
        );
      });
    }
    super.log(level, "$message",
        error: error, stackTrace: level == Level.error ? stackTrace : null);
  }

  /// Simple log logs to file without stack trace and console output
  void simpleLog(dynamic message) async {
    String dir = (await getApplicationSupportDirectory()).path;
    final String logDir = p.join(dir, "logs");
    final String filename = p.join(logDir, "kazumi_logs.log");

    final directory = Directory(logDir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    await KazumiLogger._logLock.synchronized(() async {
      await File(filename).writeAsString(
        "**${DateTime.now()}** \n$message \n",
        mode: FileMode.writeOnlyAppend,
      );
    });
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
