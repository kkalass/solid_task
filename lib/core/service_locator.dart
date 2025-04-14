import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:solid_task/models/item_operation.dart';
import 'package:solid_task/services/auth/implementations/solid_auth_service_impl.dart';
import 'package:solid_task/services/auth/interfaces/auth_state_change_provider.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/services/auth/implementations/solid_provider_service_impl.dart';
import 'package:solid_task/services/auth/interfaces/solid_provider_service.dart';
import 'package:solid_task/services/auth/jwt_decoder_wrapper.dart';
import 'package:solid_task/services/auth/solid_auth_wrapper.dart';
import 'package:solid_task/services/rdf/item_rdf_service.dart';
import 'package:solid_task/services/rdf/rdf_parser.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/repository/operation_repository.dart';
import 'package:solid_task/services/repository/solid_item_repository.dart';
import 'package:solid_task/services/repository/syncable_item_repository.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/storage/operation_storage.dart';
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
  final SolidProviderService? providerService;

  /// Secure storage implementation for auth service
  final FlutterSecureStorage? secureStorage;

  final JwtDecoderWrapper? jwtDecoder;

  /// SolidAuth implementation for auth service
  final SolidAuth? solidAuth;

  final SolidAuthState? authState;
  final AuthStateChangeProvider? authStateChangeProvider;
  final SolidAuthOperations? authOperations;

  /// Item repository implementation
  final ItemRepository Function(
    LocalStorageService storage,
    LoggerService logger,
  )?
  itemRepositoryFactory;

  /// Sync service implementation
  final SyncService Function(
    ItemRepository repository,
    SolidAuthOperations authOperations,
    SolidAuthState authState,
    LoggerService logger,
    http.Client client,
  )?
  syncServiceFactory;

  /// Sync manager factory
  final SyncManager Function(
    SyncService syncService,
    SolidAuthState authState,
    AuthStateChangeProvider authStateChangeProvider,
    LoggerService logger,
  )?
  syncManagerFactory;

  /// Syncable repository factory
  final ItemRepository Function(
    ItemRepository baseRepository,
    SyncManager syncManager,
  )?
  syncableRepositoryFactory;

  /// RDF parser implementation
  final RdfParser? rdfParser;

  /// Operation repository implementation
  final OperationRepository Function(
    Box<dynamic> box,
    ContextLogger logger,
  )? operationRepositoryFactory;

  /// ItemRdfService implementation
  final ItemRdfService Function(
    ContextLogger logger,
  )? itemRdfServiceFactory;

  /// Creates a new service locator configuration
  const ServiceLocatorConfig({
    this.loggerService,
    this.httpClient,
    this.storageService,
    this.providerService,
    this.authOperations,
    this.authState,
    this.authStateChangeProvider,
    this.secureStorage,
    this.solidAuth,
    this.itemRepositoryFactory,
    this.syncServiceFactory,
    this.syncManagerFactory,
    this.jwtDecoder,
    this.syncableRepositoryFactory,
    this.rdfParser,
    this.operationRepositoryFactory,
    this.itemRdfServiceFactory,
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

  // Register RDF parser
  sl.registerLazySingleton<RdfParser>(
    () => config.rdfParser ?? DefaultRdfParser(loggerService: sl<LoggerService>()),
  );

  // Register storage service
  sl.registerSingletonAsync<LocalStorageService>(() async {
    if (config.storageService != null) {
      return config.storageService!;
    }
    return HiveStorageService.create(loggerService: sl<LoggerService>());
  });

  // Verwende die verbesserte OperationStorage-Klasse
  sl.registerSingletonAsync<Box<dynamic>>(() async {
    return await OperationStorage.openOperationBox();
  }, instanceName: 'operationBox');

  // Register operation repository
  sl.registerSingletonAsync<OperationRepository>(() async {
    await sl.isReady<Box<dynamic>>(instanceName: 'operationBox');
    
    if (config.operationRepositoryFactory != null) {
      final box = sl<Box<dynamic>>(instanceName: 'operationBox');
      final logger = sl<LoggerService>().createLogger('OperationRepository');
      return config.operationRepositoryFactory!(box, logger);
    }
    
    // Use the factory method instead of direct constructor
    return OperationRepository.create(
      loggerService: sl<LoggerService>(),
    );
  });

  // Register ItemRdfService
  sl.registerLazySingleton<ItemRdfService>(() {
    final logger = sl<LoggerService>().createLogger('ItemRdfService');

    return config.itemRdfServiceFactory != null
        ? config.itemRdfServiceFactory!(logger)
        : ItemRdfService(logger: logger);
  });

  // Provider service with configurable implementation
  sl.registerLazySingleton<SolidProviderService>(
    () =>
        config.providerService ??
        SolidProviderServiceImpl(
          logger: sl<LoggerService>().createLogger("SolidProviderService"),
        ),
  );

  // SolidAuth wrapper with configurable implementation
  sl.registerLazySingleton<SolidAuth>(() => config.solidAuth ?? SolidAuth());

  // Auth service - use async registration since creation is asynchronous
  // There is actually a single implementation class for multiple distinct interfaces
  if (config.authOperations == null ||
      config.authState == null ||
      config.authStateChangeProvider == null) {
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
    if (config.authOperations == null) {
      sl.registerLazySingleton<SolidAuthOperations>(
        () => sl<SolidAuthServiceImpl>(),
      );
    }
    if (config.authState == null) {
      sl.registerLazySingleton<SolidAuthState>(
        () => sl<SolidAuthServiceImpl>(),
      );
    }
    if (config.authStateChangeProvider == null) {
      sl.registerLazySingleton<AuthStateChangeProvider>(
        () => sl<SolidAuthServiceImpl>(),
      );
    }
  }
  if (config.authOperations != null) {
    sl.registerLazySingleton<SolidAuthOperations>(() => config.authOperations!);
  }
  if (config.authState != null) {
    sl.registerLazySingleton<SolidAuthState>(() => config.authState!);
  }
  if (config.authStateChangeProvider != null) {
    sl.registerLazySingleton<AuthStateChangeProvider>(
      () => config.authStateChangeProvider!,
    );
  }

  // Wait for async dependencies to be ready before continuing
  await sl.allReady();

  // Item repository - depends on storage
  sl.registerLazySingleton<ItemRepository>(() {
    ItemRepository baseRepository;

    if (config.itemRepositoryFactory != null) {
      baseRepository = config.itemRepositoryFactory!(
        sl<LocalStorageService>(),
        sl<LoggerService>(),
      );
    } else {
      baseRepository = SolidItemRepository(
        storage: sl<LocalStorageService>(),
        operationRepository: sl<OperationRepository>(),
        logger: sl<LoggerService>().createLogger('ItemRepository'),
      );
    }

    // Don't wrap with SyncableItemRepository yet - we need SyncManager first
    return baseRepository;
  }, instanceName: 'baseRepository');

  // Sync service - depends on repository and auth
  sl.registerLazySingleton<SyncService>(
    () =>
        config.syncServiceFactory != null
            ? config.syncServiceFactory!(
              sl<ItemRepository>(instanceName: 'baseRepository'),
              sl<SolidAuthOperations>(),
              sl<SolidAuthState>(),
              sl<LoggerService>(),
              sl<http.Client>(),
            )
            : SolidSyncService(
              repository: sl<ItemRepository>(instanceName: 'baseRepository'),
              operationRepository: sl<OperationRepository>(),
              authOperations: sl<SolidAuthOperations>(),
              authState: sl<SolidAuthState>(),
              logger: sl<LoggerService>().createLogger('SyncService'),
              client: sl<http.Client>(),
              rdfService: sl<ItemRdfService>(),
              rdfParser: sl<RdfParser>(),
            ),
  );

  // Register SyncManager that orchestrates synchronization
  sl.registerSingletonAsync<SyncManager>(() async {
    final syncManager =
        config.syncManagerFactory != null
            ? config.syncManagerFactory!(
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

  // Register the syncable repository decorator that integrates with SyncManager
  sl.registerSingleton<ItemRepository>(
    config.syncableRepositoryFactory != null
        ? config.syncableRepositoryFactory!(
          sl<ItemRepository>(instanceName: 'baseRepository'),
          sl<SyncManager>(),
        )
        : SyncableItemRepository(
          sl<ItemRepository>(instanceName: 'baseRepository'),
          sl<SyncManager>(),
        ),
  );
}
