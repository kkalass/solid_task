import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

/// A logger that adds context to log messages.
class ContextLogger {
  final String _context;
  final LoggerService _logger;

  ContextLogger(this._context, this._logger);

  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.debug('[$_context] $message', error, stackTrace);
  }

  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.info('[$_context] $message', error, stackTrace);
  }

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.warning('[$_context] $message', error, stackTrace);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.error('[$_context] $message', error, stackTrace);
  }
}

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  static final _logger = Logger('MyAppLogger');

  // Static initializer for console logging
  static void _setupConsoleLogging() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print('${record.level.name}: ${record.time}: ${record.message}');
      if (record.error != null) {
        // ignore: avoid_print
        print('Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        // ignore: avoid_print
        print('Stack trace:\n${record.stackTrace}');
      }
    });
  }

  factory LoggerService() {
    return _instance;
  }

  /// Creates a new logger with the given context.
  /// The context will be prepended to all log messages.
  ContextLogger createLogger(String context) {
    return ContextLogger(context, this);
  }

  LoggerService._internal() {
    _setupConsoleLogging(); // Setup console logging when first instance is created
  }

  File? _logFile;
  int _maxLogSize = 1024 * 1024; // 1MB
  int _maxLogFiles = 5;
  // Add a lock to ensure sequential processing
  final _processingLock = Lock();
  StreamSubscription<LogRecord>? _logSubscription;

  /// Configure the logger with custom limits
  void configure({int? maxLogSize, int? maxLogFiles}) {
    if (maxLogSize != null) {
      _maxLogSize = maxLogSize;
    }
    if (maxLogFiles != null) {
      _maxLogFiles = maxLogFiles;
    }
  }

  Future<void> init() async {
    if (!kIsWeb) {
      try {
        await _processingLock.synchronized(() async {
          _logFile = File(
            '${(await getApplicationDocumentsDirectory()).path}/app.log',
          );
          if (!await _logFile!.exists()) {
            await _logFile!.create();
          }
        });

        // Remove any existing subscription before adding a new one
        await _logSubscription?.cancel();
        _logSubscription = Logger.root.onRecord.listen(_handleFileLogging);
      } catch (e) {
        // Use print directly to avoid potential infinite loop
        // ignore: avoid_print
        print('Failed to initialize log file: $e');
      }
    }
  }

  Future<void> _handleFileLogging(LogRecord record) async {
    if (_logFile == null) return;

    // Use a lock to ensure sequential processing
    await _processingLock.synchronized(() async {
      try {
        // Check if we need to rotate logs
        var length = await _logFile!.length();
        if (length > _maxLogSize) {
          await _rotateLogs();
          // After rotation, create a new file and get its length
          length = await _logFile!.length();
        }

        // Write the main message
        final message =
            '${record.time} ${record.loggerName}:${record.level.name}: ${record.message}\n';

        // Check if adding this message would exceed the limit
        if (length + message.length > _maxLogSize) {
          await _rotateLogs();
        }
        await _logFile!.writeAsString(message, mode: FileMode.append);

        // Write error if present
        if (record.error != null) {
          final errorMessage = 'Error: ${record.error}\n';
          length = await _logFile!.length();
          if (length + errorMessage.length > _maxLogSize) {
            await _rotateLogs();
          }
          await _logFile!.writeAsString(errorMessage, mode: FileMode.append);
        }

        // Write stack trace if present
        if (record.stackTrace != null) {
          final stackMessage = 'Stack trace:\n${record.stackTrace}\n';
          length = await _logFile!.length();
          if (length + stackMessage.length > _maxLogSize) {
            await _rotateLogs();
          }
          await _logFile!.writeAsString(stackMessage, mode: FileMode.append);
        }
      } catch (e) {
        // Use print directly to avoid potential infinite loop
        // ignore: avoid_print
        print('Failed to write to log file: $e');
      }
    });
  }

  /// Rotate log files by moving current log to a numbered backup
  Future<void> _rotateLogs() async {
    if (_logFile == null) return;

    try {
      final baseName = _logFile!.path.split('/').last;
      final basePath = _logFile!.path.substring(
        0,
        _logFile!.path.length - baseName.length,
      );

      // Delete oldest log if we've reached max files
      final oldestLog = File('$basePath$baseName.${_maxLogFiles - 1}');
      if (await oldestLog.exists()) {
        await oldestLog.delete();
      }

      // Shift all existing log files up by one
      for (var i = _maxLogFiles - 2; i >= 0; i--) {
        final oldFile = File('$basePath$baseName.$i');
        if (await oldFile.exists()) {
          await oldFile.rename('$basePath$baseName.${i + 1}');
        }
      }

      // Move current log to .0
      final currentLog = _logFile!;
      final newLogPath = '$basePath$baseName.0';
      await currentLog.rename(newLogPath);

      // Create a new empty log file and ensure it's ready
      _logFile = File('$basePath$baseName');
      await _logFile!.create();
      // Ensure the file is ready by writing an empty string
      await _logFile!.writeAsString('', mode: FileMode.write);
    } catch (e) {
      // Use print directly to avoid potential infinite loop
      // ignore: avoid_print
      print('Failed to rotate logs: $e');
      // Try to recover by creating a new log file
      try {
        final baseName = _logFile!.path.split('/').last;
        final basePath = _logFile!.path.substring(
          0,
          _logFile!.path.length - baseName.length,
        );
        _logFile = File('$basePath$baseName');
        await _logFile!.create();
        await _logFile!.writeAsString('', mode: FileMode.write);
      } catch (e) {
        // ignore: avoid_print
        print('Failed to recover log file: $e');
      }
    }
  }

  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.fine(message, error, stackTrace);
  }

  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.info(message, error, stackTrace);
  }

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.warning(message, error, stackTrace);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }

  Future<String?> getLogContents() async {
    if (_logFile == null) return null;

    return await _processingLock.synchronized(() async {
      try {
        return await _logFile!.readAsString();
      } catch (e) {
        _logger.severe('Failed to read log file', e);
        return null;
      }
    });
  }

  /// Get contents of all rotated log files
  Future<List<String>> getAllLogContents() async {
    if (_logFile == null) return [];

    return await _processingLock.synchronized(() async {
      final baseName = _logFile!.path.split('/').last;
      final basePath = _logFile!.path.substring(
        0,
        _logFile!.path.length - baseName.length,
      );

      final logs = <String>[];

      // First add the current log file
      try {
        final content = await _logFile!.readAsString();
        logs.add('=== Current log file ===\n$content');
      } catch (e) {
        _logger.severe('Failed to read current log file', e);
      }

      // Then add rotated log files
      for (var i = 0; i < _maxLogFiles; i++) {
        final logFile = File('$basePath$baseName.$i');
        if (await logFile.exists()) {
          try {
            final content = await logFile.readAsString();
            logs.add('=== Rotated log file $i ===\n$content');
          } catch (e) {
            _logger.severe('Failed to read rotated log file $i', e);
          }
        }
      }

      return logs;
    });
  }

  Future<void> dispose() async {
    await _logSubscription?.cancel();
    _logSubscription = null;
  }
}
