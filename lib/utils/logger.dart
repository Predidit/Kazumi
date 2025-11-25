import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

const Symbol _forceLogKey = #_forceLog;

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

class KazumiLogPrinter extends PrettyPrinter {
  KazumiLogPrinter()
      : super(
          methodCount: 0,
          errorMethodCount:
              8,
          lineLength: 120,
          colors: true,
          // Disable emojis for better compatibility
          printEmojis: false,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        );

  @override
  List<String> log(LogEvent event) {
    // For trace, debug, info - never show stack trace
    if (event.level == Level.trace ||
        event.level == Level.debug ||
        event.level == Level.info) {
      final messageStr = stringifyMessage(event.message);
      final time = getTime(event.time);
      final prefix = _getPrefix(event.level);
      final levelName = _getLevelName(event.level);

      return [
        '$prefix $time $levelName $messageStr',
      ];
    }

    // For warning, error, fatal - use default behavior which shows stack if provided
    return super.log(event);
  }

  /// Colored prefix for log level
  String _getPrefix(Level level) {
    if (!colors) return _getLevelTag(level);

    const reset = '\x1B[0m';
    String colorCode;

    switch (level) {
      case Level.trace:
        colorCode = '\x1B[90m'; // Bright Black
      case Level.debug:
        colorCode = '\x1B[36m'; // Cyan
      case Level.info:
        colorCode = '\x1B[32m'; // Green
      case Level.warning:
        colorCode = '\x1B[33m'; // Yellow
      case Level.error:
        colorCode = '\x1B[31m'; // Red
      case Level.fatal:
        colorCode = '\x1B[35m'; // Magenta
      default:
        colorCode = '';
    }

    return '$colorCode${_getLevelTag(level)}$reset';
  }

  /// Tag symbol for log level
  String _getLevelTag(Level level) {
    switch (level) {
      case Level.trace:
        return '[·]';
      case Level.debug:
        return '[*]';
      case Level.info:
        return '[i]';
      case Level.warning:
        return '[!]';
      case Level.error:
        return '[×]';
      case Level.fatal:
        return '[‼]';
      default:
        return '[-]';
    }
  }

  String _getLevelName(Level level) {
    return level.name.toUpperCase().padRight(7);
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

        final timestamp = DateTime.now().toString();

        final buffer = StringBuffer();
        buffer.writeln('[$timestamp]');
        for (var line in event.lines) {
          final cleanLine = _removeAnsiCodes(line);
          buffer.writeln(cleanLine);
        }
        buffer.writeln();

        await file.writeAsString(
          buffer.toString(),
          mode: FileMode.writeOnlyAppend,
        );
      } catch (e) {
        print('Failed to write log to file: $e');
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
    _log(() => _logger.t(message, error: error, stackTrace: stackTrace), forceLog);
  }

  /// Debug log - detailed information for debugging
  void d(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(() => _logger.d(message, error: error, stackTrace: stackTrace), forceLog);
  }

  /// Info log - informational messages
  void i(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(() => _logger.i(message, error: error, stackTrace: stackTrace), forceLog);
  }

  /// Warning log - potentially harmful situations
  void w(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(() => _logger.w(message, error: error, stackTrace: stackTrace), forceLog);
  }

  /// Error log - error events that might still allow the app to continue
  void e(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(() => _logger.e(message, error: error, stackTrace: stackTrace), forceLog);
  }

  /// Fatal log - very severe error events that will presumably lead the app to abort
  void f(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(() => _logger.f(message, error: error, stackTrace: stackTrace), forceLog);
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
    print('Error clearing file: $e');
    return false;
  }
}
