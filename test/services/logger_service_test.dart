import 'package:flutter_test/flutter_test.dart';
import 'package:my_cross_platform_app/services/logger_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'dart:io';

class MockPathProvider extends PathProviderPlatform {
  late Directory _tempDir;

  MockPathProvider() {
    _tempDir = Directory.systemTemp.createTempSync('logger_test');
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return _tempDir.path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return _tempDir.path;
  }

  @override
  Future<String?> getTemporaryPath() async {
    return _tempDir.path;
  }

  @override
  Future<String?> getLibraryPath() async {
    return _tempDir.path;
  }

  @override
  Future<String?> getApplicationCachePath() async {
    return _tempDir.path;
  }

  @override
  Future<String?> getExternalStoragePath() async {
    return _tempDir.path;
  }

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async {
    return [_tempDir.path];
  }

  @override
  Future<String?> getDownloadsPath() async {
    return _tempDir.path;
  }
}

void main() {
  late LoggerService logger;
  late Directory tempDir;
  late File logFile;

  setUpAll(() {
    PathProviderPlatform.instance = MockPathProvider();
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
      for (var i = 0; i < 3; i++) {
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
      for (var i = 0; i < 7; i++) {
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
      var allContentsOrig = await logger.getAllLogContents();
      // Create multiple log files
      final largeMessage = 'x' * 5000; // Large message to trigger rotation
      for (var i = 0; i < 3; i++) {
        logger.info('Message $i');
        allContentsOrig = await logger.getAllLogContents();
        logger.info(largeMessage);
        allContentsOrig = await logger.getAllLogContents();
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
}
