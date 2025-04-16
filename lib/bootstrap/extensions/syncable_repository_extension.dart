import 'package:get_it/get_it.dart';
import 'package:solid_task/bootstrap/service_locator_builder.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/repository/syncable_item_repository.dart';
import 'package:solid_task/ext/solid/sync/sync_manager.dart';

/// Extension for ServiceLocatorBuilder to handle Sync services
extension SyncableRepositoryServiceLocatorBuilderExtension
    on ServiceLocatorBuilder {
  // Configuration sync
  static final Map<ServiceLocatorBuilder, _SyncableRepositoryConfig> _configs =
      {};

  /// Sets the syncable repository factory
  ServiceLocatorBuilder withSyncableRepositoryFactory(
    ItemRepository Function(GetIt sl) factory,
  ) {
    _configs[this]!._syncableRepositoryFactory = factory;
    return this;
  }

  /// Register Sync services during the build phase
  Future<void> registerSyncableRepository(GetIt sl) async {
    assert(
      _configs[this] == null,
      'Syncable repositories have already been registered for this builder instance.',
    );
    _configs[this] = _SyncableRepositoryConfig();
    registerBuildHook(() async {
      final config = _configs[this]!;

      // Register the syncable repository decorator that integrates with SyncManager
      var syncableRepositoryFactory = config._syncableRepositoryFactory;
      sl.registerSingleton<ItemRepository>(
        syncableRepositoryFactory != null
            ? syncableRepositoryFactory(sl)
            : SyncableItemRepository(
              sl<ItemRepository>(instanceName: 'baseRepository'),
              sl<SyncManager>(),
            ),
      );

      // Clean up after registration
      _configs.remove(this);
    });
  }
}

/// Private class to hold service configurations
class _SyncableRepositoryConfig {
  ItemRepository Function(GetIt sl)? _syncableRepositoryFactory;

  _SyncableRepositoryConfig();
}
