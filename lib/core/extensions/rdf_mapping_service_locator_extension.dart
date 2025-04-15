import 'package:solid_task/core/service_locator.dart';
import 'package:solid_task/core/service_locator_builder.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/mapping/item_rdf_mapper.dart';
import 'package:solid_task/services/rdf/mapping/rdf_mapper_registry.dart';
import 'package:solid_task/services/rdf/mapping/rdf_mapper_service.dart';
import 'package:solid_task/services/rdf/mapping/rdf_type_converter.dart';

/// Extension for ServiceLocatorBuilder to handle RDF mapping services
extension RdfMappingServiceLocatorBuilderExtension on ServiceLocatorBuilder {
  // Configuration storage
  static final Map<ServiceLocatorBuilder, _RdfMappingConfig> _configs = {};

  /// Configuration for RDF mapping services
  ServiceLocatorBuilder withRdfMappingServices({
    RdfMapperRegistry? registry,
    RdfTypeConverter? typeConverter,
    RdfMapperService? mapperService,
    ItemRdfMapper? itemMapper,
  }) {
    _configs[this]!
      .._registry = registry
      .._typeConverter = typeConverter
      .._mapperService = mapperService
      .._itemMapper = itemMapper;

    return this;
  }

  /// Register RDF mapping services during the build phase
  Future<void> registerRdfMappingServices() async {
    assert(
      _configs[this] == null,
      'RDF mapping services have already been registered for this builder instance.',
    );
    _configs[this] = _RdfMappingConfig();
    registerBuildHook(() async {
      final config = _configs[this]!;

      final loggerService = sl<LoggerService>();

      // Register type converter
      sl.registerLazySingleton<RdfTypeConverter>(
        () =>
            config._typeConverter ??
            RdfTypeConverter(loggerService: loggerService),
      );

      // Register mapper registry
      sl.registerLazySingleton<RdfMapperRegistry>(
        () =>
            config._registry ?? RdfMapperRegistry(loggerService: loggerService),
      );

      // Register item mapper
      sl.registerLazySingleton<ItemRdfMapper>(
        () =>
            config._itemMapper ??
            ItemRdfMapper(
              loggerService: loggerService,
              typeConverter: sl<RdfTypeConverter>(),
            ),
      );

      // Register mapper service
      sl.registerLazySingleton<RdfMapperService>(() {
        // Use provided mapper service or create a new one
        final service =
            config._mapperService ??
            RdfMapperService(
              registry: sl<RdfMapperRegistry>(),
              loggerService: loggerService,
              typeConverter: sl<RdfTypeConverter>(),
            );

        // Register the item mapper with the registry
        service.registry.registerMapper<Item>(sl<ItemRdfMapper>());

        return service;
      });

      // Clean up after registration
      _configs.remove(this);
    });
  }
}

/// Private class to hold RDF mapping configuration
class _RdfMappingConfig {
  RdfMapperRegistry? _registry;
  RdfTypeConverter? _typeConverter;
  RdfMapperService? _mapperService;
  ItemRdfMapper? _itemMapper;

  _RdfMappingConfig();
}
