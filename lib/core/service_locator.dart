import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:solid_task/services/auth/auth_service.dart';
import 'package:solid_task/services/auth/solid_auth_service.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/repository/solid_item_repository.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/sync/sync_service.dart';
import 'package:solid_task/services/sync/solid_sync_service.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';
import 'package:solid_task/services/storage/hive_storage_service.dart';

// Global ServiceLocator instance
final sl = GetIt.instance;

/// Initialize dependency injection in the correct order to avoid circular dependencies
Future<void> initServiceLocator() async {
  // Core services - synchronous registrations first
  sl.registerSingleton<LoggerService>(LoggerService());
  sl.registerLazySingleton<http.Client>(() => http.Client());
  
  // Register storage service
  sl.registerSingleton<LocalStorageService>(HiveStorageService());
  
  // Initialize storage (needs to be done before using it)
  await sl<LocalStorageService>().init();
  
  // Auth service - independent of other services
  sl.registerLazySingleton<AuthService>(
    () => SolidAuthService(
      logger: sl<LoggerService>().createLogger('AuthService'),
      client: sl<http.Client>(),
    ),
  );
  
  // Item repository - depends on storage
  sl.registerLazySingleton<ItemRepository>(
    () => SolidItemRepository(
      storage: sl<LocalStorageService>(),
      logger: sl<LoggerService>().createLogger('ItemRepository'),
    ),
  );
  
  // Sync service - depends on repository and auth
  sl.registerLazySingleton<SyncService>(
    () => SolidSyncService(
      repository: sl<ItemRepository>(),
      authService: sl<AuthService>(),
      logger: sl<LoggerService>().createLogger('SyncService'),
      client: sl<http.Client>(),
    ),
  );
}
