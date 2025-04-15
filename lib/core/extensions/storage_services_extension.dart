import 'package:solid_task/core/service_locator.dart';
import 'package:solid_task/core/service_locator_builder.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/storage/hive_storage_service.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';

/// Extension for ServiceLocatorBuilder to handle Core services
extension StorageServiceLocatorBuilderExtension on ServiceLocatorBuilder {
  // Configuration storage
  static final Map<ServiceLocatorBuilder, _StorageConfig> _configs = {};

  /// Sets the storage service implementation
  ServiceLocatorBuilder withStorageService(LocalStorageService storageService) {
    _configs[this]!._storageService = storageService;
    return this;
  }

  /// Register Storage services during the build phase
  Future<void> registerStorageServices() async {
    assert(
      _configs[this] == null,
      'Storage services have already been registered for this builder instance.',
    );
    _configs[this] = _StorageConfig();
    registerBuildHook(() async {
      final config = _configs[this]!;

      // Register storage service
      sl.registerSingletonAsync<LocalStorageService>(() async {
        final storageService = config._storageService;
        if (storageService != null) {
          return storageService;
        }
        return HiveStorageService.create(loggerService: sl<LoggerService>());
      });

      // Wait for storage to be ready
      await sl.isReady<LocalStorageService>();

      // Clean up after registration
      _configs.remove(this);
    });
  }
}

/// Private class to hold service configurations
class _StorageConfig {
  LocalStorageService? _storageService;

  _StorageConfig();
}
