import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

const Symbol _forceLogKey = #_forceLog;

String _singleLineLogText(Object? value) {
  return value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

class KazumiLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    final forceLog = Zone.current[_forceLogKey] as bool? ?? false;
    if (forceLog) {
      return true;
    }
    return event.level.index >= Logger.level.index;
  }
}

class KazumiLogPrinter extends LogPrinter {
  static const int _fatalStackFrameLimit = 8;

  @override
  List<String> log(LogEvent event) {
    final time = _formatTime(event.time);
    final level = _colorizeLevel(event.level);
    final message = _singleLineLogText(_stringifyMessage(event.message));
    final error =
        event.error == null ? '' : ' | ${_singleLineLogText(event.error)}';
    final lines = <String>['$time $level $message$error'];

    if (event.level == Level.fatal) {
      lines.addAll(_formatStackTrace(event.stackTrace ?? StackTrace.current));
    }

    return lines;
  }

  String _colorizeLevel(Level level) {
    const reset = '\x1B[0m';
    final color = switch (level) {
      Level.trace => '\x1B[90m',
      Level.debug => '\x1B[36m',
      Level.info => '\x1B[32m',
      Level.warning => '\x1B[33m',
      Level.error => '\x1B[31m',
      Level.fatal => '\x1B[35m',
      _ => '',
    };
    final name = level.name.toUpperCase().padRight(7);
    return '$color$name$reset';
  }

  String _formatTime(DateTime time) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final milliseconds = time.millisecond.toString().padLeft(3, '0');
    return '${twoDigits(time.hour)}:${twoDigits(time.minute)}:'
        '${twoDigits(time.second)}.$milliseconds';
  }

  String _stringifyMessage(dynamic message) {
    final value = message is Function ? message() : message;
    if (value is Map || value is Iterable) {
      try {
        return jsonEncode(
          value,
          toEncodable: (object) => object.toString(),
        );
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }

  Iterable<String> _formatStackTrace(StackTrace stackTrace) {
    return stackTrace
        .toString()
        .split('\n')
        .where((line) =>
            line.trim().isNotEmpty &&
            !line.contains('package:logger/') &&
            !line.contains('package:kazumi/services/logging/logger.dart'))
        .take(_fatalStackFrameLimit)
        .map((line) => '  ${line.trim()}');
  }
}

class KazumiLogOutput extends LogOutput {
  static final Lock _logLock = Lock();
  static String? _logFilePath;

  static Future<String> _getLogFilePath() async {
    if (_logFilePath != null) return _logFilePath!;

    final dir = (await getApplicationSupportDirectory()).path;
    final logDir = p.join(dir, "logs");
    final directory = Directory(logDir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _logFilePath = p.join(logDir, "kazumi_logs.log");
    return _logFilePath!;
  }

  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      print(line);
    }

    // Write to file if: warning/error/fatal OR forceLog is enabled
    final forceLog = Zone.current[_forceLogKey] as bool? ?? false;
    if (event.level.index >= Level.warning.index || forceLog) {
      _writeToFile(event);
    }
  }

  void _writeToFile(OutputEvent event) {
    _logLock.synchronized(() async {
      try {
        final filePath = await _getLogFilePath();
        final file = File(filePath);

        final buffer = StringBuffer();
        for (var line in event.lines) {
          final cleanLine = _removeAnsiCodes(line);
          buffer.writeln(cleanLine);
        }

        await file.writeAsString(
          buffer.toString(),
          mode: FileMode.writeOnlyAppend,
        );
      } catch (e) {
        print('Failed to write log to file: ${_singleLineLogText(e)}');
      }
    });
  }

  /// Remove ANSI escape codes from string to ensure clean log files
  String _removeAnsiCodes(String text) {
    return text.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
  }
}

class KazumiLogger {
  KazumiLogger._internal() {
    _logger = Logger(
      filter: KazumiLogFilter(),
      printer: KazumiLogPrinter(),
      output: KazumiLogOutput(),
    );
  }

  static final KazumiLogger _instance = KazumiLogger._internal();
  factory KazumiLogger() {
    return _instance;
  }

  late final Logger _logger;
  void _log(void Function() logFn, bool forceLog) {
    if (forceLog) {
      runZoned(logFn, zoneValues: {_forceLogKey: true});
    } else {
      logFn();
    }
  }

  /// Trace log - lowest level, very detailed information
  void t(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(() => _logger.t(message, error: error), forceLog);
  }

  /// Debug log - detailed information for debugging
  void d(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(() => _logger.d(message, error: error), forceLog);
  }

  /// Info log - informational messages
  void i(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(() => _logger.i(message, error: error), forceLog);
  }

  /// Warning log - potentially harmful situations
  void w(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(() => _logger.w(message, error: error), forceLog);
  }

  /// Error log - error events that might still allow the app to continue
  void e(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(() => _logger.e(message, error: error), forceLog);
  }

  /// Fatal log - very severe error events that may cause the app to abort.
  void f(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(
      () => _logger.f(
        message,
        error: error,
        stackTrace: stackTrace ?? StackTrace.current,
      ),
      forceLog,
    );
  }
}

Future<File> getLogsPath() async {
  final dir = (await getApplicationSupportDirectory()).path;
  final logDir = p.join(dir, "logs");
  final filename = p.join(logDir, "kazumi_logs.log");

  final directory = Directory(logDir);
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final file = File(filename);
  if (!await file.exists()) {
    await KazumiLogOutput._logLock.synchronized(() async {
      if (!await file.exists()) {
        await file.create();
      }
    });
  }
  return file;
}

Future<bool> clearLogs() async {
  try {
    final file = await getLogsPath();
    await KazumiLogOutput._logLock.synchronized(() async {
      await file.writeAsString('');
    });
    return true;
  } catch (e) {
    print('Error clearing file: ${_singleLineLogText(e)}');
    return false;
  }
}
