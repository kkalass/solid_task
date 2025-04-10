import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:io';

/// MockTempDirPathProvider is a mock implementation of PathProviderPlatform
/// that creates and uses a temporary directory for all path queries.
///
/// This makes it ideal for unit tests that need to interact with the file system
/// without affecting the real application directories.
class MockTempDirPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  /// The temporary directory used for all path requests
  late Directory _tempDir;

  /// Creates a new MockTempDirPathProvider with a unique temporary directory
  ///
  /// [prefix] - A string prefix for the temporary directory name to identify the test context.
  /// This helps distinguish between different test suites or scenarios.
  MockTempDirPathProvider({required String prefix}) {
    _tempDir = Directory.systemTemp.createTempSync(prefix);
  }

  /// Gets the temporary directory path created for testing
  String get tempDirPath => _tempDir.path;

  /// Cleans up the temporary directory
  Future<void> cleanup() async {
    if (_tempDir.existsSync()) {
      await _tempDir.delete(recursive: true);
    }
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
