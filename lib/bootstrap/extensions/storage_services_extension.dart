import 'package:get_it/get_it.dart';

import 'package:solid_task/bootstrap/service_locator_builder.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/storage/hive_storage_service.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';

/// Extension for ServiceLocatorBuilder to handle Core services
extension StorageServiceLocatorBuilderExtension on ServiceLocatorBuilder {
  // Configuration storage
  static final Map<ServiceLocatorBuilder, _StorageConfig> _configs = {};

  /// Sets the storage service implementation
  ServiceLocatorBuilder withStorageServiceFactory(
    LocalStorageService Function(GetIt) factory,
  ) {
    _configs[this]!._storageServiceFactory = factory;
    return this;
  }

  /// Register Storage services during the build phase
  Future<void> registerStorageServices(GetIt sl) async {
    assert(
      _configs[this] == null,
      'Storage services have already been registered for this builder instance.',
    );
    _configs[this] = _StorageConfig();
    registerBuildHook(() async {
      final config = _configs[this]!;

      // Register storage service
      sl.registerSingletonAsync<LocalStorageService>(
        () async {
          final storageServiceFactory = config._storageServiceFactory;
          if (storageServiceFactory != null) {
            return storageServiceFactory(sl);
          }
          return HiveStorageService.create(loggerService: sl<LoggerService>());
        },
        dispose: (storage) async {
          // HiveStorageService has a close() method instead of dispose()
          if (storage is HiveStorageService) {
            await storage.close();
          }
        },
      );

      // Wait for storage to be ready
      await sl.isReady<LocalStorageService>();

      // Clean up after registration
      _configs.remove(this);
    });
  }
}

/// Private class to hold service configurations
class _StorageConfig {
  LocalStorageService Function(GetIt)? _storageServiceFactory;

  _StorageConfig();
}
