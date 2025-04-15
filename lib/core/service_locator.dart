import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:solid_task/services/auth/implementations/solid_auth_service_impl.dart';
import 'package:solid_task/services/auth/interfaces/auth_state_change_provider.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/services/auth/implementations/solid_provider_service_impl.dart';
import 'package:solid_task/services/auth/interfaces/solid_provider_service.dart';
import 'package:solid_task/services/auth/jwt_decoder_wrapper.dart';
import 'package:solid_task/services/auth/solid_auth_wrapper.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/repository/solid_item_repository.dart';
import 'package:solid_task/services/repository/syncable_item_repository.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/sync/sync_manager.dart';
import 'package:solid_task/services/sync/sync_service.dart';
import 'package:solid_task/services/sync/solid_sync_service.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';
import 'package:solid_task/services/storage/hive_storage_service.dart';

/// Global ServiceLocator instance
final sl = GetIt.instance;

/// Provides a fluent API for building and configuring the service locator
class ServiceLocatorBuilder {
  // Core services
  LoggerService? _loggerService;
  http.Client? _httpClient;
  FlutterSecureStorage? _secureStorage;
  JwtDecoderWrapper? _jwtDecoder;

  // Storage
  LocalStorageService? _storageService;

  // Auth services
  SolidProviderService? _providerService;
  SolidAuth? _solidAuth;
  SolidAuthState? _authState;
  AuthStateChangeProvider? _authStateChangeProvider;
  SolidAuthOperations? _authOperations;

  // Repository factories
  ItemRepository Function(LocalStorageService storage, LoggerService logger)?
  _itemRepositoryFactory;

  // Sync services
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

  ItemRepository Function(
    ItemRepository baseRepository,
    SyncManager syncManager,
  )?
  _syncableRepositoryFactory;

  /// Sets the logger service implementation
  ServiceLocatorBuilder withLogger(LoggerService logger) {
    _loggerService = logger;
    return this;
  }

  /// Sets the HTTP client implementation
  ServiceLocatorBuilder withHttpClient(http.Client client) {
    _httpClient = client;
    return this;
  }

  /// Sets the secure storage implementation
  ServiceLocatorBuilder withSecureStorage(FlutterSecureStorage secureStorage) {
    _secureStorage = secureStorage;
    return this;
  }

  /// Sets the JWT decoder implementation
  ServiceLocatorBuilder withJwtDecoder(JwtDecoderWrapper jwtDecoder) {
    _jwtDecoder = jwtDecoder;
    return this;
  }

  /// Sets the storage service implementation
  ServiceLocatorBuilder withStorageService(LocalStorageService storageService) {
    _storageService = storageService;
    return this;
  }

  /// Sets the provider service implementation
  ServiceLocatorBuilder withProviderService(
    SolidProviderService providerService,
  ) {
    _providerService = providerService;
    return this;
  }

  /// Sets the SolidAuth implementation
  ServiceLocatorBuilder withSolidAuth(SolidAuth solidAuth) {
    _solidAuth = solidAuth;
    return this;
  }

  /// Sets all auth-related services at once (convenience method)
  ServiceLocatorBuilder withAuthServices({
    SolidAuthState? authState,
    AuthStateChangeProvider? authStateChangeProvider,
    SolidAuthOperations? authOperations,
  }) {
    _authState = authState;
    _authStateChangeProvider = authStateChangeProvider;
    _authOperations = authOperations;
    return this;
  }

  /// Sets the item repository factory
  ServiceLocatorBuilder withItemRepositoryFactory(
    ItemRepository Function(LocalStorageService storage, LoggerService logger)
    factory,
  ) {
    _itemRepositoryFactory = factory;
    return this;
  }

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
    _syncServiceFactory = factory;
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
    _syncManagerFactory = factory;
    return this;
  }

  /// Sets the syncable repository factory
  ServiceLocatorBuilder withSyncableRepositoryFactory(
    ItemRepository Function(
      ItemRepository baseRepository,
      SyncManager syncManager,
    )
    factory,
  ) {
    _syncableRepositoryFactory = factory;
    return this;
  }

  /// Builds and initializes the service locator with all configured services
  Future<void> build() async {
    // First register the most basic services (synchronous registrations)
    _registerCoreServices();

    // Then register storage - depends on logger
    await _registerStorageServices();

    // Register auth-related services - depends on core and storage
    await _registerAuthServices();

    // Register domain repositories and services - depends on auth and storage
    _registerRepositoryServices();

    // Register sync services - depends on repositories and auth
    await _registerSyncServices();

    // Finally register the syncable repository that depends on everything else
    _registerSyncableRepository();
  }

  void _registerCoreServices() {
    // Register logger first since it's used by almost everything
    sl.registerSingleton<LoggerService>(_loggerService ?? LoggerService());

    // Register HTTP client
    sl.registerLazySingleton<http.Client>(() => _httpClient ?? http.Client());

    // Register secure storage
    sl.registerSingleton<FlutterSecureStorage>(
      _secureStorage ?? const FlutterSecureStorage(),
    );

    // Register JWT decoder
    sl.registerSingleton<JwtDecoderWrapper>(_jwtDecoder ?? JwtDecoderWrapper());
  }

  Future<void> _registerStorageServices() async {
    // Register storage service
    sl.registerSingletonAsync<LocalStorageService>(() async {
      if (_storageService != null) {
        return _storageService!;
      }
      return HiveStorageService.create(loggerService: sl<LoggerService>());
    });

    // Wait for storage to be ready
    await sl.isReady<LocalStorageService>();
  }

  Future<void> _registerAuthServices() async {
    // Provider service with configurable implementation
    sl.registerLazySingleton<SolidProviderService>(
      () =>
          _providerService ??
          SolidProviderServiceImpl(
            logger: sl<LoggerService>().createLogger("SolidProviderService"),
          ),
    );

    // SolidAuth wrapper with configurable implementation
    sl.registerLazySingleton<SolidAuth>(() => _solidAuth ?? SolidAuth());

    // Auth service - use async registration since creation is asynchronous
    // Register all interfaces from the same implementation if they're not explicitly provided
    if (_authOperations == null ||
        _authState == null ||
        _authStateChangeProvider == null) {
      sl.registerSingletonAsync<SolidAuthServiceImpl>(() async {
        // Create the standard auth service
        return await SolidAuthServiceImpl.create(
          loggerService: sl<LoggerService>(),
          client: sl<http.Client>(),
          providerService: sl<SolidProviderService>(),
          secureStorage: sl<FlutterSecureStorage>(),
          solidAuth: sl<SolidAuth>(),
          jwtDecoder: sl<JwtDecoderWrapper>(),
        );
      });

      await sl.isReady<SolidAuthServiceImpl>();

      // Register interfaces from the same implementation
      if (_authOperations == null) {
        sl.registerLazySingleton<SolidAuthOperations>(
          () => sl<SolidAuthServiceImpl>(),
        );
      }

      if (_authState == null) {
        sl.registerLazySingleton<SolidAuthState>(
          () => sl<SolidAuthServiceImpl>(),
        );
      }

      if (_authStateChangeProvider == null) {
        sl.registerLazySingleton<AuthStateChangeProvider>(
          () => sl<SolidAuthServiceImpl>(),
        );
      }
    }

    // Register custom implementations if provided
    if (_authOperations != null) {
      sl.registerLazySingleton<SolidAuthOperations>(() => _authOperations!);
    }

    if (_authState != null) {
      sl.registerLazySingleton<SolidAuthState>(() => _authState!);
    }

    if (_authStateChangeProvider != null) {
      sl.registerLazySingleton<AuthStateChangeProvider>(
        () => _authStateChangeProvider!,
      );
    }
  }

  void _registerRepositoryServices() {
    // Item repository - depends on storage
    sl.registerLazySingleton<ItemRepository>(() {
      if (_itemRepositoryFactory != null) {
        return _itemRepositoryFactory!(
          sl<LocalStorageService>(),
          sl<LoggerService>(),
        );
      } else {
        return SolidItemRepository(
          storage: sl<LocalStorageService>(),
          logger: sl<LoggerService>().createLogger('ItemRepository'),
        );
      }
    }, instanceName: 'baseRepository');
  }

  Future<void> _registerSyncServices() async {
    // Sync service - depends on repository and auth
    sl.registerLazySingleton<SyncService>(() {
      if (_syncServiceFactory != null) {
        return _syncServiceFactory!(
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
      final syncManager =
          _syncManagerFactory != null
              ? _syncManagerFactory!(
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
  }

  void _registerSyncableRepository() {
    // Register the syncable repository decorator that integrates with SyncManager
    sl.registerSingleton<ItemRepository>(
      _syncableRepositoryFactory != null
          ? _syncableRepositoryFactory!(
            sl<ItemRepository>(instanceName: 'baseRepository'),
            sl<SyncManager>(),
          )
          : SyncableItemRepository(
            sl<ItemRepository>(instanceName: 'baseRepository'),
            sl<SyncManager>(),
          ),
    );
  }
}

/// Initialize dependency injection using the builder pattern
///
/// This function creates a default ServiceLocatorBuilder and allows customization
/// before building the service locator.
Future<void> initServiceLocator({
  void Function(ServiceLocatorBuilder builder)? configure,
}) async {
  final builder = ServiceLocatorBuilder();

  // Allow caller to configure the builder
  if (configure != null) {
    configure(builder);
  }

  // Build and initialize the service locator
  await builder.build();
}
