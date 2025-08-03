import 'package:get_it/get_it.dart';
import 'package:solid_task/bootstrap/extensions/auth_services_extension.dart';
import 'package:solid_task/bootstrap/extensions/client_id_services_extension.dart';
import 'package:solid_task/bootstrap/extensions/core_services_extension.dart';
import 'package:solid_task/bootstrap/extensions/rdf_mapping_service_locator_extension.dart';
import 'package:solid_task/bootstrap/extensions/repository_services_extension.dart';
import 'package:solid_task/bootstrap/extensions/storage_services_extension.dart';
import 'package:solid_task/bootstrap/extensions/sync_services_extension.dart';
import 'package:solid_task/bootstrap/extensions/syncable_repository_extension.dart';
import 'package:solid_task/bootstrap/service_locator_builder.dart';

export 'package:solid_task/bootstrap/extensions/auth_services_extension.dart';
export 'package:solid_task/bootstrap/extensions/client_id_services_extension.dart';
export 'package:solid_task/bootstrap/extensions/core_services_extension.dart';
export 'package:solid_task/bootstrap/extensions/rdf_mapping_service_locator_extension.dart';
export 'package:solid_task/bootstrap/extensions/repository_services_extension.dart';
export 'package:solid_task/bootstrap/extensions/storage_services_extension.dart';
export 'package:solid_task/bootstrap/extensions/sync_services_extension.dart';
export 'package:solid_task/bootstrap/extensions/syncable_repository_extension.dart';

/// Global ServiceLocator instance
final sl = GetIt.instance;

/// Initialize dependency injection using the builder pattern
///
/// This function creates a default ServiceLocatorBuilder, and allows additional customization before building.
Future<void> initServiceLocator({
  void Function(ServiceLocatorBuilder builder)? configure,
}) async {
  final builder = ServiceLocatorBuilder();

  // !!! START ACTIVATE EXTENSIONS
  // First register the most basic services (synchronous registrations)
  builder.registerCoreServices(sl);

  // Register client ID service early - depends on secure storage from core services
  builder.registerClientIdServices(sl);

  // Then register storage - depends on logger from core services
  builder.registerStorageServices(sl);

  // Configure RDF mapping services by default
  // Uses extension method to register the services but only during build phase
  builder.registerRdfMappingServices(sl);

  // Register auth-related services - depends on core and storage
  builder.registerAuthServices(sl);

  // Register domain repositories and services - depends on auth and storage
  builder.registerRepositoryServices(sl);

  // Register sync services - depends on repositories and auth
  builder.registerSyncServices(sl);

  // Finally register the syncable repository that depends on everything else
  builder.registerSyncableRepository(sl);
  // !!! END ACTIVATE EXTENSIONS

  // Allow caller to configure the builder (potentially overriding defaults)
  if (configure != null) {
    configure(builder);
  }

  // Build and initialize the service locator
  await builder.build();
}

/// Properly dispose all services that implement disposal
///
/// This function should be called when the app is shutting down to ensure
/// proper cleanup of resources like timers, streams, files, etc.
/// GetIt will automatically handle calling dispose() on registered services.
Future<void> disposeServiceLocator() async {
  // GetIt's reset() method automatically calls dispose() on all registered
  // services that were registered with a dispose callback
  await sl.reset();
}
