import 'package:get_it/get_it.dart';
import 'package:solid_task/bootstrap/service_locator_builder.dart';
import 'package:solid_task/ext/solid/auth/interfaces/auth_state_change_provider.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/ext/rdf_orm/rdf_mapper_service.dart';
import 'package:solid_task/ext/rdf/core/rdf_parser.dart';
import 'package:solid_task/ext/rdf/core/rdf_serializer.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/ext/solid/sync/rdf_repository.dart';
import 'package:solid_task/services/repository/solid_item_rdf_repository_adapter.dart';
import 'package:solid_task/ext/solid/pod/storage/auth_based_storage_configuration_provider.dart';
import 'package:solid_task/ext/solid/pod/storage/pod_storage_configuration_provider.dart';
import 'package:solid_task/ext/solid/pod/storage/strategy/default_triple_storage_strategy.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';
import 'package:solid_task/ext/solid/sync/solid_sync_service.dart';
import 'package:solid_task/ext/solid/sync/sync_manager.dart';
import 'package:solid_task/ext/solid/sync/sync_service.dart';
import 'package:http/http.dart' as http;

/// Extension for ServiceLocatorBuilder to handle Core services
extension SyncServiceLocatorBuilderExtension on ServiceLocatorBuilder {
  // Configuration sync
  static final Map<ServiceLocatorBuilder, _SyncConfig> _configs = {};

  /// Sets the sync service factory
  ServiceLocatorBuilder withSyncServiceFactory(
    SyncService Function(GetIt sl) factory,
  ) {
    _configs[this]!._syncServiceFactory = factory;
    return this;
  }

  /// Sets the sync manager factory
  ServiceLocatorBuilder withSyncManagerFactory(
    SyncManager Function(GetIt sl) factory,
  ) {
    _configs[this]!._syncManagerFactory = factory;
    return this;
  }

  /// Sets the PodStorageConfigurationProvider
  ServiceLocatorBuilder withPodStorageConfigurationProviderFactory(
    PodStorageConfigurationProvider Function(GetIt) factory,
  ) {
    _configs[this]!._storageConfigurationProviderFactory = factory;
    return this;
  }

  /// Register Sync services during the build phase
  Future<void> registerSyncServices(GetIt sl) async {
    assert(
      _configs[this] == null,
      'Sync services have already been registered for this builder instance.',
    );
    _configs[this] = _SyncConfig();
    registerBuildHook(() async {
      final config = _configs[this]!;

      // Sync service - depends on repository and auth
      sl.registerLazySingleton<PodStorageConfigurationProvider>(() {
        var podStorageConfigurationProviderFactory =
            config._storageConfigurationProviderFactory;
        if (podStorageConfigurationProviderFactory != null) {
          return podStorageConfigurationProviderFactory(sl);
        } else {
          return AuthBasedStorageConfigurationProvider(
            authState: sl<SolidAuthState>(),
            authStateChangeProvider: sl<AuthStateChangeProvider>(),
            storageStrategy: DefaultTripleStorageStrategy(),
          );
        }
      });

      sl.registerLazySingleton<RdfRepository>(() {
        return SolidItemRdfRepositoryAdapter(
          itemRepository: sl<ItemRepository>(instanceName: 'baseRepository'),
          storage: sl<LocalStorageService>(),
          loggerService: sl<LoggerService>(),
        );
      });

      sl.registerSingleton(RdfParserFactory());
      sl.registerSingleton(RdfSerializerFactory());

      // Sync service - depends on repository and auth
      sl.registerLazySingleton<SyncService>(() {
        var syncServiceFactory = config._syncServiceFactory;
        if (syncServiceFactory != null) {
          return syncServiceFactory(sl);
        } else {
          return SolidSyncService(
            repository: sl<RdfRepository>(),
            authOperations: sl<SolidAuthOperations>(),
            authState: sl<SolidAuthState>(),
            client: sl<http.Client>(),
            rdfMapperService: sl<RdfMapperService>(),
            configProvider: sl<PodStorageConfigurationProvider>(),
            rdfParserFactory: sl<RdfParserFactory>(),
            rdfSerializerFactory: sl<RdfSerializerFactory>(),
          );
        }
      });

      // Register SyncManager that orchestrates synchronization
      sl.registerSingletonAsync<SyncManager>(() async {
        var syncManagerFactory = config._syncManagerFactory;
        final syncManager =
            syncManagerFactory != null
                ? syncManagerFactory(sl)
                : SyncManager(
                  sl<SyncService>(),
                  sl<SolidAuthState>(),
                  sl<AuthStateChangeProvider>(),
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
  SyncService Function(GetIt sl)? _syncServiceFactory;

  SyncManager Function(GetIt sl)? _syncManagerFactory;

  PodStorageConfigurationProvider Function(GetIt)?
  _storageConfigurationProviderFactory;

  _SyncConfig();
}
