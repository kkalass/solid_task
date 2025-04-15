import 'package:get_it/get_it.dart';
import 'package:solid_task/core/extensions/auth_services_extension.dart';
import 'package:solid_task/core/extensions/core_services_extension.dart';
import 'package:solid_task/core/extensions/repository_services_extension.dart';
import 'package:solid_task/core/extensions/storage_services_extension.dart';
import 'package:solid_task/core/extensions/sync_services_extension.dart';
import 'package:solid_task/core/extensions/syncable_repository_extension.dart';
import 'package:solid_task/core/service_locator_builder.dart';
import 'package:solid_task/core/extensions/rdf_mapping_service_locator_extension.dart';

export 'package:solid_task/core/extensions/auth_services_extension.dart';
export 'package:solid_task/core/extensions/core_services_extension.dart';
export 'package:solid_task/core/extensions/repository_services_extension.dart';
export 'package:solid_task/core/extensions/storage_services_extension.dart';
export 'package:solid_task/core/extensions/sync_services_extension.dart';
export 'package:solid_task/core/extensions/syncable_repository_extension.dart';
export 'package:solid_task/core/extensions/rdf_mapping_service_locator_extension.dart';

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
  builder.registerCoreServices();

  // Then register storage - depends on logger from core services
  builder.registerStorageServices();

  // Configure RDF mapping services by default
  // Uses extension method to register the services but only during build phase
  builder.registerRdfMappingServices();

  // Register auth-related services - depends on core and storage
  builder.registerAuthServices();

  // Register domain repositories and services - depends on auth and storage
  builder.registerRepositoryServices();

  // Register sync services - depends on repositories and auth
  builder.registerSyncServices();

  // Finally register the syncable repository that depends on everything else
  builder.registerSyncableRepository();
  // !!! END ACTIVATE EXTENSIONS

  // Allow caller to configure the builder (potentially overriding defaults)
  if (configure != null) {
    configure(builder);
  }

  // Build and initialize the service locator
  await builder.build();
}
