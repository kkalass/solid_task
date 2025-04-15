import 'package:solid_task/core/service_locator.dart';
import 'package:solid_task/core/service_locator_builder.dart';
import 'package:solid_task/services/auth/interfaces/auth_state_change_provider.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/sync/solid_sync_service.dart';
import 'package:solid_task/services/sync/sync_manager.dart';
import 'package:solid_task/services/sync/sync_service.dart';
import 'package:http/http.dart' as http;

/// Extension for ServiceLocatorBuilder to handle Core services
extension SyncServiceLocatorBuilderExtension on ServiceLocatorBuilder {
  // Configuration sync
  static final Map<ServiceLocatorBuilder, _SyncConfig> _configs = {};

  /// Sets the sync service factory
  ServiceLocatorBuilder withSyncServiceFactory(
    SyncService Function(
      ItemRepository repository,
      SolidAuthOperations authOperations,
      SolidAuthState authState,
      LoggerService logger,
      http.Client client,
    )
    factory,
  ) {
    _configs[this]!._syncServiceFactory = factory;
    return this;
  }

  /// Sets the sync manager factory
  ServiceLocatorBuilder withSyncManagerFactory(
    SyncManager Function(
      SyncService syncService,
      SolidAuthState authState,
      AuthStateChangeProvider authStateChangeProvider,
      LoggerService logger,
    )
    factory,
  ) {
    _configs[this]!._syncManagerFactory = factory;
    return this;
  }

  /// Register Sync services during the build phase
  Future<void> registerSyncServices() async {
    assert(
      _configs[this] == null,
      'Sync services have already been registered for this builder instance.',
    );
    _configs[this] = _SyncConfig();
    registerBuildHook(() async {
      final config = _configs[this]!;

      // Sync service - depends on repository and auth
      sl.registerLazySingleton<SyncService>(() {
        var syncServiceFactory = config._syncServiceFactory;
        if (syncServiceFactory != null) {
          return syncServiceFactory(
            sl<ItemRepository>(instanceName: 'baseRepository'),
            sl<SolidAuthOperations>(),
            sl<SolidAuthState>(),
            sl<LoggerService>(),
            sl<http.Client>(),
          );
        } else {
          return SolidSyncService(
            repository: sl<ItemRepository>(instanceName: 'baseRepository'),
            authOperations: sl<SolidAuthOperations>(),
            authState: sl<SolidAuthState>(),
            loggerService: sl<LoggerService>(),
            client: sl<http.Client>(),
          );
        }
      });

      // Register SyncManager that orchestrates synchronization
      sl.registerSingletonAsync<SyncManager>(() async {
        var syncManagerFactory = config._syncManagerFactory;
        final syncManager =
            syncManagerFactory != null
                ? syncManagerFactory(
                  sl<SyncService>(),
                  sl<SolidAuthState>(),
                  sl<AuthStateChangeProvider>(),
                  sl<LoggerService>(),
                )
                : SyncManager(
                  sl<SyncService>(),
                  sl<SolidAuthState>(),
                  sl<AuthStateChangeProvider>(),
                  sl<LoggerService>().createLogger('SyncManager'),
                );

        // Initialize the sync manager
        await syncManager.initialize();
        return syncManager;
      });

      // Wait for SyncManager to be ready
      await sl.isReady<SyncManager>();

      // Clean up after registration
      _configs.remove(this);
    });
  }
}

/// Private class to hold service configurations
class _SyncConfig {
  SyncService Function(
    ItemRepository repository,
    SolidAuthOperations authOperations,
    SolidAuthState authState,
    LoggerService logger,
    http.Client client,
  )?
  _syncServiceFactory;

  SyncManager Function(
    SyncService syncService,
    SolidAuthState authState,
    AuthStateChangeProvider authStateChangeProvider,
    LoggerService logger,
  )?
  _syncManagerFactory;

  _SyncConfig();
}
