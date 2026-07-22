import 'dart:io';

import 'package:kazumi/services/logging/log_sanitizer.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

class KazumiLogBackend {
  KazumiLogBackend._();

  static final Lock _lock = Lock();
  static String? _logFilePath;

  static void writeConsole(String line) {
    stdout.writeln(LogSanitizer.sanitizeText(line));
  }

  static void writePersistent(Iterable<String> lines) {
    _lock.synchronized(() async {
      try {
        final file = File(await _ensureLogPath());
        final buffer = StringBuffer()..writeln('[${DateTime.now()}]');
        for (final line in lines) {
          buffer.writeln(
            LogSanitizer.sanitizeText(
              line.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), ''),
            ),
          );
        }
        buffer.writeln();
        await file.writeAsString(
          buffer.toString(),
          mode: FileMode.writeOnlyAppend,
        );
      } catch (error) {
        stderr.writeln(
          LogSanitizer.sanitizeText('Failed to write log to file: $error'),
        );
      }
    });
  }

  static Future<String> _ensureLogPath() async {
    if (_logFilePath != null) return _logFilePath!;
    final dir = (await getApplicationSupportDirectory()).path;
    final logDir = p.join(dir, 'logs');
    final directory = Directory(logDir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _logFilePath = p.join(logDir, 'kazumi_logs.log');
    return _logFilePath!;
  }

  static Future<dynamic> getLogsPath() async {
    final file = File(await _ensureLogPath());
    if (!await file.exists()) {
      await _lock.synchronized(() async {
        if (!await file.exists()) await file.create();
      });
    }
    return file;
  }

  static Future<bool> clearLogs() async {
    try {
      final File file = await getLogsPath();
      await _lock.synchronized(() => file.writeAsString(''));
      return true;
    } catch (error) {
      stderr.writeln(
        LogSanitizer.sanitizeText('Error clearing file: $error'),
      );
      return false;
    }
  }
}
