import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'dart:io';
import 'dart:async';
import 'package:logging/logging.dart';
import '../mocks/mock_temp_dir_path_provider.dart';

void main() {
  late LoggerService logger;
  late Directory tempDir;
  late File logFile;
  late MockTempDirPathProvider mockPathProvider;

  setUpAll(() {
    mockPathProvider = MockTempDirPathProvider(prefix: 'test_logger_service');
    PathProviderPlatform.instance = mockPathProvider;
  });

  tearDownAll(() async {
    await mockPathProvider.cleanup();
  });

  setUp(() async {
    // Clean up any existing log files first
    tempDir = await getApplicationDocumentsDirectory();
    logFile = File('${tempDir.path}/app.log');

    // Wait for any pending operations to complete
    await Future.delayed(const Duration(milliseconds: 100));

    // Clean up all possible log files
    if (await logFile.exists()) {
      await logFile.delete();
    }
    for (var i = 0; i < 10; i++) {
      // Use a larger number to catch any rotated files
      final rotatedFile = File('${tempDir.path}/app.log.$i');
      if (await rotatedFile.exists()) {
        await rotatedFile.delete();
      }
    }

    logger = LoggerService();
    // Configure with larger limits for testing to accommodate stack traces
    logger.configure(maxLogSize: 10 * 1024, maxLogFiles: 3); // 10KB max size
    await logger.init();
    // Wait for logger to initialize
    await Future.delayed(const Duration(milliseconds: 50));
  });

  tearDown(() async {
    // Wait for any pending writes to complete
    await Future.delayed(const Duration(milliseconds: 100));

    // Dispose of the logger to clean up listeners
    await logger.dispose();

    // Clean up all possible log files
    if (await logFile.exists()) {
      await logFile.delete();
    }
    for (var i = 0; i < 10; i++) {
      // Use a larger number to catch any rotated files
      final rotatedFile = File('${tempDir.path}/app.log.$i');
      if (await rotatedFile.exists()) {
        await rotatedFile.delete();
      }
    }
  });

  group('LoggerService', () {
    test('should be a singleton', () {
      final logger1 = LoggerService();
      final logger2 = LoggerService();
      expect(logger1, equals(logger2));
    });

    test('should initialize log file', () async {
      expect(await logFile.exists(), isTrue);
    });

    test('should log debug messages', () async {
      logger.debug('Test debug message');
      await Future.delayed(const Duration(milliseconds: 50));
      final contents = await logFile.readAsString();
      expect(contents, contains('Test debug message'));
      expect(contents, contains('FINE'));
    });

    test('should log info messages', () async {
      logger.info('Test info message');
      await Future.delayed(const Duration(milliseconds: 50));
      final contents = await logFile.readAsString();
      expect(contents, contains('Test info message'));
      expect(contents, contains('INFO'));
    });

    test('should log warning messages', () async {
      logger.warning('Test warning message');
      await Future.delayed(const Duration(milliseconds: 50));
      final contents = await logFile.readAsString();
      expect(contents, contains('Test warning message'));
      expect(contents, contains('WARNING'));
    });

    test('should log error messages', () async {
      logger.error('Test error message');
      await Future.delayed(const Duration(milliseconds: 50));
      final contents = await logFile.readAsString();
      expect(contents, contains('Test error message'));
      expect(contents, contains('SEVERE'));
    });

    test('should log errors with stack traces', () async {
      try {
        throw Exception('Test exception');
      } catch (e, st) {
        logger.error('Test error', e, st);
      }
      await Future.delayed(const Duration(milliseconds: 50));
      final contents = await logFile.readAsString();
      expect(contents, contains('Test error'));
      expect(contents, contains('Exception: Test exception'));
      expect(contents, contains('Stack trace:'));
    });

    test('should rotate logs when size limit is reached', () async {
      // Fill the log file to trigger rotation
      // Each log message includes:
      // - Timestamp (about 30 chars)
      // - Logger name (about 10 chars)
      // - Log level (about 5 chars)
      // - Newlines (2 chars)
      // Total overhead per message: ~47 chars
      final largeMessage =
          'x' * 4000; // Large message to trigger rotation with 10KB limit

      // Write messages until rotation occurs
      var rotationOccurred = false;
      for (var i = 0; i < 4; i++) {
        logger.info(largeMessage);
        await Future.delayed(const Duration(milliseconds: 50));

        // Check if rotation has occurred
        final rotatedFile = File('${tempDir.path}/app.log.0');
        if (await rotatedFile.exists()) {
          rotationOccurred = true;
          break;
        }
      }

      expect(
        rotationOccurred,
        isTrue,
        reason: 'Log rotation should have occurred',
      );

      // Verify the current log file is smaller than max size
      final currentSize = await logFile.length();
      expect(
        currentSize,
        lessThan(10 * 1024),
        reason: 'Current log file should be smaller than max size',
      );

      // Verify the rotated file exists and has content
      final rotatedFile = File('${tempDir.path}/app.log.0');
      final rotatedSize = await rotatedFile.length();
      expect(
        rotatedSize,
        greaterThan(0),
        reason: 'Rotated file should have content',
      );
    });

    test('should maintain max number of rotated files', () async {
      // Fill the log file multiple times to trigger multiple rotations
      final largeMessage = 'x' * 5000; // Large message to trigger rotation
      for (var i = 0; i < 10; i++) {
        logger.info(largeMessage);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Check that we have the correct number of rotated files
      for (var i = 0; i < 3; i++) {
        final rotatedFile = File('${tempDir.path}/app.log.$i');
        expect(await rotatedFile.exists(), isTrue);
      }

      // Check that older files are deleted
      final excessFile = File('${tempDir.path}/app.log.3');
      expect(await excessFile.exists(), isFalse);
    });

    test('should retrieve log contents', () async {
      const testMessage = 'Test message for getLogContents';
      logger.info(testMessage);
      await Future.delayed(const Duration(milliseconds: 50));

      final contents = await logger.getLogContents();
      expect(contents, isNotNull);
      expect(contents, contains(testMessage));
    });

    test('should retrieve all rotated log contents', () async {
      // Create multiple log files
      final largeMessage = 'x' * 5000; // Large message to trigger rotation
      for (var i = 0; i < 3; i++) {
        logger.info('Message $i');
        logger.info(largeMessage);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final allContents = await logger.getAllLogContents();
      expect(allContents.length, greaterThan(1));
      expect(allContents[1], contains('=== Rotated log file 0 ==='));
      expect(allContents[1], contains('Message 0'));
    });

    test('should handle file system errors gracefully', () async {
      // Delete the log file to simulate an error
      await logFile.delete();

      // Try to log a message
      logger.info('Test message');
      await Future.delayed(const Duration(milliseconds: 50));

      // The logger should not crash and should handle the error
      expect(await logFile.exists(), isFalse);
    });
  });

  group('ContextLogger', () {
    late ContextLogger contextLogger;
    late List<LogRecord> capturedLogs;
    late StreamSubscription<LogRecord> logSubscription;

    setUp(() {
      contextLogger = logger.createLogger('TestContext');
      capturedLogs = [];

      // Capture logs instead of printing them
      logSubscription = Logger.root.onRecord.listen((record) {
        capturedLogs.add(record);
      });
    });

    tearDown(() {
      // Clean up the log listener
      logSubscription.cancel();
      capturedLogs.clear();
    });

    test('should prepend context to debug messages', () {
      contextLogger.debug('Test message');
      expect(capturedLogs.length, equals(1));
      expect(capturedLogs[0].message, equals('[TestContext] Test message'));
      expect(capturedLogs[0].level, equals(Level.FINE));
    });

    test('should prepend context to info messages', () {
      contextLogger.info('Test message');
      expect(capturedLogs.length, equals(1));
      expect(capturedLogs[0].message, equals('[TestContext] Test message'));
      expect(capturedLogs[0].level, equals(Level.INFO));
    });

    test('should prepend context to warning messages', () {
      contextLogger.warning('Test message');
      expect(capturedLogs.length, equals(1));
      expect(capturedLogs[0].message, equals('[TestContext] Test message'));
      expect(capturedLogs[0].level, equals(Level.WARNING));
    });

    test('should prepend context to error messages', () {
      contextLogger.error('Test message');
      expect(capturedLogs.length, equals(1));
      expect(capturedLogs[0].message, equals('[TestContext] Test message'));
      expect(capturedLogs[0].level, equals(Level.SEVERE));
    });

    test('should include error object in log record', () {
      final error = Exception('Test error');
      contextLogger.error('Test message', error);
      expect(capturedLogs.length, equals(1));
      expect(capturedLogs[0].error, equals(error));
    });

    test('should include stack trace in log record', () {
      final stackTrace = StackTrace.current;
      contextLogger.error('Test message', null, stackTrace);
      expect(capturedLogs.length, equals(1));
      expect(capturedLogs[0].stackTrace, equals(stackTrace));
    });

    test('should handle multiple contexts', () {
      final logger1 = logger.createLogger('Context1');
      final logger2 = logger.createLogger('Context2');

      logger1.debug('Message 1');
      logger2.debug('Message 2');

      expect(capturedLogs.length, equals(2));
      expect(capturedLogs[0].message, equals('[Context1] Message 1'));
      expect(capturedLogs[1].message, equals('[Context2] Message 2'));
    });

    test('should handle empty messages', () {
      contextLogger.debug('');
      expect(capturedLogs.length, equals(1));
      expect(capturedLogs[0].message, equals('[TestContext] '));
    });

    test('should handle special characters in context', () {
      final specialLogger = logger.createLogger('Special-Context_123');
      specialLogger.debug('Test message');
      expect(capturedLogs.length, equals(1));
      expect(
        capturedLogs[0].message,
        equals('[Special-Context_123] Test message'),
      );
    });
  });
}
