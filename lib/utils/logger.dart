import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class KazumiLogger extends Logger {
  KazumiLogger._internal() : super();
  static final KazumiLogger _instance = KazumiLogger._internal();

  factory KazumiLogger() {
    return _instance;
  }

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

      await File(filename).writeAsString(
        "**${DateTime.now()}** \n$message \n${stackTrace == null ? '' : stackTrace.toString()} \n",
        mode: FileMode.writeOnlyAppend,
      );
    }
    super.log(level, "$message", error: error, stackTrace: level == Level.error ? stackTrace : null);
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
    await file.create();
  }
  return file;
}

Future<bool> clearLogs() async {
  String dir = (await getApplicationSupportDirectory()).path;
  final String logDir = p.join(dir, "logs");
  final String filename = p.join(logDir, "kazumi_logs.log");

  // 确保日志文件夹存在
  final directory = Directory(logDir);
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final file = File(filename);
  try {
    await file.writeAsString('');
  } catch (e) {
    print('Error clearing file: $e');
    return false;
  }
  return true;
}
