import 'package:meta/meta.dart';
import 'package:solid_task/ext/solid/pod/storage/pod_storage_configuration.dart';
import 'package:solid_task/ext/solid/pod/storage/pod_storage_configuration_provider.dart';

/// Static provider with fixed configuration, useful for testing and special cases
@immutable
final class StaticStorageConfigurationProvider
    implements PodStorageConfigurationProvider {
  final PodStorageConfiguration? _configuration;

  /// Creates a provider with fixed configuration
  const StaticStorageConfigurationProvider(this._configuration);

  @override
  PodStorageConfiguration? get currentConfiguration => _configuration;

  @override
  Future<PodStorageConfiguration?> refreshConfiguration() async =>
      _configuration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaticStorageConfigurationProvider &&
          runtimeType == other.runtimeType &&
          _configuration == other._configuration;

  @override
  int get hashCode => _configuration.hashCode;
}
