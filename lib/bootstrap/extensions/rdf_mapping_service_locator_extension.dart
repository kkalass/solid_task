import 'package:get_it/get_it.dart';
import 'package:solid_task/bootstrap/service_locator_builder.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/solid_integration/item_rdf_mapper.dart';
import 'package:solid_task/ext/rdf_orm/rdf_mapper_registry.dart';
import 'package:solid_task/ext/rdf_orm/rdf_mapper_service.dart';

/// Extension for ServiceLocatorBuilder to handle RDF mapping services
extension RdfMappingServiceLocatorBuilderExtension on ServiceLocatorBuilder {
  // Configuration storage
  static final Map<ServiceLocatorBuilder, _RdfMappingConfig> _configs = {};

  /// Configuration for RDF mapping services
  ServiceLocatorBuilder withRdfMapperRegistryFactory(
    RdfMapperRegistry Function(GetIt)? factory,
  ) {
    _configs[this]!._registryFactory = factory;

    return this;
  }

  ServiceLocatorBuilder withRdfMapperServiceFactory(
    RdfMapperService Function(GetIt)? factory,
  ) {
    _configs[this]!._mapperServiceFactory = factory;

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
      sl.registerLazySingleton<RdfMapperRegistry>(() {
        final factory = config._registryFactory;
        return factory == null ? RdfMapperRegistry() : factory(sl);
      });

      // Register item mapper
      sl.registerLazySingleton<ItemRdfMapper>(() {
        final factory = config._itemMapperFactory;
        return factory == null
            ? ItemRdfMapper(loggerService: loggerService)
            : factory(sl);
      });

      // Register mapper service
      sl.registerLazySingleton<RdfMapperService>(() {
        // Use provided mapper service or create a new one
        final factory = config._mapperServiceFactory;
        final service =
            factory == null
                ? RdfMapperService(registry: sl<RdfMapperRegistry>())
                : factory(sl);

        // Register the item mapper with the registry
        service.registry.registerSubjectMapper<Item>(sl<ItemRdfMapper>());

        return service;
      });

      // Clean up after registration
      _configs.remove(this);
    });
  }
}

/// Private class to hold RDF mapping configuration
class _RdfMappingConfig {
  RdfMapperRegistry Function(GetIt)? _registryFactory;
  RdfMapperService Function(GetIt)? _mapperServiceFactory;
  ItemRdfMapper Function(GetIt)? _itemMapperFactory;

  _RdfMappingConfig();
}
