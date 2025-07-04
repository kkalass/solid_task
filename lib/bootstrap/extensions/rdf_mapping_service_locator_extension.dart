import 'package:get_it/get_it.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:solid_task/bootstrap/service_locator_builder.dart';
import 'package:solid_task/ext/solid/pod/storage/pod_storage_configuration_provider.dart';
import 'package:solid_task/init_rdf_mapper.g.dart';

/// Extension for ServiceLocatorBuilder to handle RDF mapping services
extension RdfMappingServiceLocatorBuilderExtension on ServiceLocatorBuilder {
  // Configuration storage
  static final Map<ServiceLocatorBuilder, _RdfMappingConfig> _configs = {};

  /// Configuration for RDF mapping services
  ServiceLocatorBuilder withRdfMapper(RdfMapper Function(GetIt)? factory) {
    _configs[this]!._rdfMapperFactory = factory;

    return this;
  }

  ServiceLocatorBuilder withRdfCore(RdfCore Function(GetIt)? factory) {
    _configs[this]!._rdfCoreFactory = factory;

    return this;
  }

  /// Register RDF mapping services during the build phase
  Future<void> registerRdfMappingServices(GetIt sl) async {
    assert(
      _configs[this] == null,
      'RDF mapping services have already been registered for this builder instance.',
    );
    _configs[this] = _RdfMappingConfig();
    registerBuildHook(() async {
      final config = _configs[this]!;

      // Register mapper registry
      sl.registerLazySingleton<RdfCore>(() {
        final factory = config._rdfCoreFactory;
        return factory == null ? RdfCore.withStandardCodecs() : factory(sl);
      });

      // Register mapper service
      sl.registerLazySingleton<RdfMapper>(() {
        final podStorageConfigurationProvider =
            sl<PodStorageConfigurationProvider>();

        // Use provided mapper service or create a new one
        final factory = config._rdfMapperFactory;
        final rdfMapper = factory == null
            ? RdfMapper(registry: RdfMapperRegistry(), rdfCore: sl<RdfCore>())
            : factory(sl);
        return initRdfMapper(
          rdfMapper: rdfMapper,
          storageRootProvider: () => podStorageConfigurationProvider
              .currentConfiguration!
              .appStorageRoot
              .replaceFirst(RegExp(r'/$'), ''),
        );
      });

      // Clean up after registration
      _configs.remove(this);
    });
  }
}

/// Private class to hold RDF mapping configuration
class _RdfMappingConfig {
  RdfMapper Function(GetIt)? _rdfMapperFactory;
  RdfCore Function(GetIt)? _rdfCoreFactory;

  _RdfMappingConfig();
}
