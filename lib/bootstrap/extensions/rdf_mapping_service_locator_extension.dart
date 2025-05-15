import 'package:get_it/get_it.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:solid_task/bootstrap/service_locator_builder.dart';
import 'package:solid_task/ext/solid/pod/storage/pod_storage_configuration_provider.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/solid_integration/item_rdf_mapper.dart';

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

  ServiceLocatorBuilder withItemRdfMapperFactory(
    ItemRdfMapper Function(GetIt)? factory,
  ) {
    _configs[this]!._itemMapperFactory = factory;

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

      final loggerService = sl<LoggerService>();

      // Register mapper registry
      sl.registerLazySingleton<RdfCore>(() {
        final factory = config._rdfCoreFactory;
        return factory == null ? RdfCore.withStandardCodecs() : factory(sl);
      });

      // Register item mapper
      sl.registerLazySingleton<ItemRdfMapper>(() {
        final podStorageConfigurationProvider =
            sl<PodStorageConfigurationProvider>();
        final factory = config._itemMapperFactory;
        return factory == null
            ? ItemRdfMapper(
              loggerService: loggerService,
              storageRootProvider:
                  () =>
                      podStorageConfigurationProvider
                          .currentConfiguration!
                          .appStorageRoot,
            )
            : factory(sl);
      });

      // Register mapper service
      sl.registerLazySingleton<RdfMapper>(() {
        // Use provided mapper service or create a new one
        final factory = config._rdfMapperFactory;
        final rdfMapper =
            factory == null
                ? RdfMapper(
                  registry: RdfMapperRegistry(),
                  rdfCore: sl<RdfCore>(),
                )
                : factory(sl);

        // Register the item mapper with the registry
        rdfMapper.registerMapper<Item>(sl<ItemRdfMapper>());

        return rdfMapper;
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
  ItemRdfMapper Function(GetIt)? _itemMapperFactory;

  _RdfMappingConfig();
}
