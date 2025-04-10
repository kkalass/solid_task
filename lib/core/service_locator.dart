import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:solid_task/services/auth/auth_service.dart';
import 'package:solid_task/services/auth/default_provider_service.dart';
import 'package:solid_task/services/auth/jwt_decoder_wrapper.dart';
import 'package:solid_task/services/auth/provider_service.dart';
import 'package:solid_task/services/auth/solid_auth_service.dart';
import 'package:solid_task/services/auth/solid_auth_wrapper.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/repository/solid_item_repository.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/sync/sync_manager.dart';
import 'package:solid_task/services/sync/sync_service.dart';
import 'package:solid_task/services/sync/solid_sync_service.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';
import 'package:solid_task/services/storage/hive_storage_service.dart';

/// Global ServiceLocator instance
final sl = GetIt.instance;

/// Service locator configuration for dependency injection
class ServiceLocatorConfig {
  /// Logger service implementation
  final LoggerService? loggerService;

  /// HTTP client implementation
  final http.Client? httpClient;

  /// Local storage service implementation
  final LocalStorageService? storageService;

  /// Provider service implementation
  final ProviderService? providerService;

  /// Auth service factory
  final Future<AuthService> Function(
    LoggerService logger,
    http.Client client,
    ProviderService providerService,
  )?
  authServiceFactory;

  /// Secure storage implementation for auth service
  final FlutterSecureStorage? secureStorage;

  final JwtDecoderWrapper? jwtDecoder;

  /// SolidAuth implementation for auth service
  final SolidAuth? solidAuth;

  /// Item repository implementation
  final ItemRepository Function(
    LocalStorageService storage,
    LoggerService logger,
  )?
  itemRepositoryFactory;

  /// Sync service implementation
  final SyncService Function(
    ItemRepository repository,
    AuthService authService,
    LoggerService logger,
    http.Client client,
  )?
  syncServiceFactory;

  /// Sync manager factory
  final SyncManager Function(
    SyncService syncService,
    AuthService authService,
    LoggerService logger,
  )?
  syncManagerFactory;

  /// Creates a new service locator configuration
  const ServiceLocatorConfig({
    this.loggerService,
    this.httpClient,
    this.storageService,
    this.providerService,
    this.authServiceFactory,
    this.secureStorage,
    this.solidAuth,
    this.itemRepositoryFactory,
    this.syncServiceFactory,
    this.syncManagerFactory,
    this.jwtDecoder,
  });
}

/// Initialize dependency injection in the correct order to avoid circular dependencies
///
/// The [config] parameter allows overriding specific service implementations,
/// which is particularly useful for testing.
Future<void> initServiceLocator({
  ServiceLocatorConfig config = const ServiceLocatorConfig(),
}) async {
  // Core services - synchronous registrations first
  sl.registerSingleton<LoggerService>(config.loggerService ?? LoggerService());

  sl.registerLazySingleton<http.Client>(
    () => config.httpClient ?? http.Client(),
  );

  sl.registerSingleton<FlutterSecureStorage>(
    config.secureStorage ?? const FlutterSecureStorage(),
  );
  sl.registerSingleton<JwtDecoderWrapper>(
    config.jwtDecoder ?? JwtDecoderWrapper(),
  );

  // Register storage service
  sl.registerSingletonAsync<LocalStorageService>(() async {
    if (config.storageService != null) {
      return config.storageService!;
    }
    return HiveStorageService.create(loggerService: sl<LoggerService>());
  });

  // Provider service with configurable implementation
  sl.registerLazySingleton<ProviderService>(
    () =>
        config.providerService ??
        DefaultProviderService(
          logger: sl<LoggerService>().createLogger("ProviderService"),
        ),
  );

  // SolidAuth wrapper with configurable implementation
  sl.registerLazySingleton<SolidAuth>(() => config.solidAuth ?? SolidAuth());

  // Auth service - use async registration since creation is asynchronous
  sl.registerSingletonAsync<AuthService>(() async {
    if (config.authServiceFactory != null) {
      return config.authServiceFactory!(
        sl<LoggerService>(),
        sl<http.Client>(),
        sl<ProviderService>(),
      );
    }

    return SolidAuthService.create(
      loggerService: sl<LoggerService>(),
      client: sl<http.Client>(),
      providerService: sl<ProviderService>(),
      secureStorage: sl<FlutterSecureStorage>(),
      solidAuth: sl<SolidAuth>(),
      jwtDecoder: sl<JwtDecoderWrapper>(),
    );
  });

  // Wait for async dependencies to be ready before continuing
  await sl.allReady();

  // Item repository - depends on storage
  sl.registerLazySingleton<ItemRepository>(
    () =>
        config.itemRepositoryFactory != null
            ? config.itemRepositoryFactory!(
              sl<LocalStorageService>(),
              sl<LoggerService>(),
            )
            : SolidItemRepository(
              storage: sl<LocalStorageService>(),
              logger: sl<LoggerService>().createLogger('ItemRepository'),
            ),
  );

  // Sync service - depends on repository and auth
  sl.registerLazySingleton<SyncService>(
    () =>
        config.syncServiceFactory != null
            ? config.syncServiceFactory!(
              sl<ItemRepository>(),
              sl<AuthService>(),
              sl<LoggerService>(),
              sl<http.Client>(),
            )
            : SolidSyncService(
              repository: sl<ItemRepository>(),
              authService: sl<AuthService>(),
              logger: sl<LoggerService>().createLogger('SyncService'),
              client: sl<http.Client>(),
            ),
  );

  // Register SyncManager that orchestrates synchronization
  sl.registerSingletonAsync<SyncManager>(() async {
    final syncManager =
        config.syncManagerFactory != null
            ? config.syncManagerFactory!(
              sl<SyncService>(),
              sl<AuthService>(),
              sl<LoggerService>(),
            )
            : SyncManager(
              sl<SyncService>(),
              sl<AuthService>(),
              sl<LoggerService>().createLogger('SyncManager'),
            );

    // Initialize the sync manager
    await syncManager.initialize();
    return syncManager;
  });

  // Wait for async dependencies to be ready before returning
  await sl.allReady();
}
