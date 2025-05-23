import 'package:get_it/get_it.dart';

import 'package:solid_task/bootstrap/service_locator_builder.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/repository/solid_item_repository.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';

/// Extension for ServiceLocatorBuilder to handle Repository services
extension RepositoryServiceLocatorBuilderExtension on ServiceLocatorBuilder {
  // Configuration storage
  static final Map<ServiceLocatorBuilder, _RepositoryConfig> _configs = {};

  /// Sets the item repository factory
  ServiceLocatorBuilder withItemRepositoryFactory(
    ItemRepository Function(GetIt) factory,
  ) {
    _configs[this]!._itemRepositoryFactory = factory;
    return this;
  }

  /// Register Repository services during the build phase
  Future<void> registerRepositoryServices(GetIt sl) async {
    assert(
      _configs[this] == null,
      'Repository services have already been registered for this builder instance.',
    );
    _configs[this] = _RepositoryConfig();
    registerBuildHook(() async {
      final config = _configs[this]!;

      // Item repository - depends on storage
      sl.registerLazySingleton<ItemRepository>(() {
        final itemRepositoryFactory = config._itemRepositoryFactory;
        if (itemRepositoryFactory != null) {
          return itemRepositoryFactory(sl);
        } else {
          return SolidItemRepository(
            storage: sl<LocalStorageService>(),
            logger: sl<LoggerService>().createLogger('ItemRepository'),
          );
        }
      }, instanceName: 'baseRepository');

      // Clean up after registration
      _configs.remove(this);
    });
  }
}

/// Private class to hold service configurations
class _RepositoryConfig {
  // Repository factories
  ItemRepository Function(GetIt sl)? _itemRepositoryFactory;

  _RepositoryConfig();
}
