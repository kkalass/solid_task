import 'package:solid_task/ext/solid/pod/storage/pod_storage_configuration.dart';

/// Provides Pod storage configuration based on external configuration sources
///
/// Abstracts the creation and management of storage configuration, decoupling
/// configuration concerns from sync service implementation.
abstract interface class PodStorageConfigurationProvider {
  /// Returns current storage configuration or null if unavailable
  PodStorageConfiguration? get currentConfiguration;

  /// Manually request configuration refresh
  Future<PodStorageConfiguration?> refreshConfiguration();
}
