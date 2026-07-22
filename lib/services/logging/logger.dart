import 'dart:async';

import 'package:logger/logger.dart';
import 'package:kazumi/services/logging/log_backend.dart';
import 'package:kazumi/services/logging/log_sanitizer.dart';

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
          errorMethodCount: 8,
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
  static bool _persistentLoggingEnabled = false;

  static void enablePersistentLogging() {
    _persistentLoggingEnabled = true;
  }

  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      KazumiLogBackend.writeConsole(LogSanitizer.sanitizeText(line));
    }

    // Write to file if: warning/error/fatal OR forceLog is enabled
    final forceLog = Zone.current[_forceLogKey] as bool? ?? false;
    if (_persistentLoggingEnabled &&
        (event.level.index >= Level.warning.index || forceLog)) {
      KazumiLogBackend.writePersistent(event.lines);
    }
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

  /// Enables path-provider-backed log files after Flutter bindings exist.
  /// Pure Dart tests still receive console output without attempting platform
  /// channel access.
  static void enablePersistentLogging() {
    KazumiLogOutput.enablePersistentLogging();
  }

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
    _log(() => _logger.t(message, error: error, stackTrace: stackTrace),
        forceLog);
  }

  /// Debug log - detailed information for debugging
  void d(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(() => _logger.d(message, error: error, stackTrace: stackTrace),
        forceLog);
  }

  /// Info log - informational messages
  void i(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(() => _logger.i(message, error: error, stackTrace: stackTrace),
        forceLog);
  }

  /// Warning log - potentially harmful situations
  void w(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(() => _logger.w(message, error: error, stackTrace: stackTrace),
        forceLog);
  }

  /// Error log - error events that might still allow the app to continue
  void e(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(() => _logger.e(message, error: error, stackTrace: stackTrace),
        forceLog);
  }

  /// Fatal log - very severe error events that will presumably lead the app to abort
  void f(dynamic message,
      {Object? error, StackTrace? stackTrace, bool forceLog = false}) {
    _log(() => _logger.f(message, error: error, stackTrace: stackTrace),
        forceLog);
  }
}

Future<dynamic> getLogsPath() => KazumiLogBackend.getLogsPath();

Future<bool> clearLogs() => KazumiLogBackend.clearLogs();
