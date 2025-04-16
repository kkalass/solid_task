import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/ext/solid/sync/rdf_repository.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';

/// Adapter that connects the ItemRepository implementation to the RdfRepository interface
///
/// This adapter allows the generic SolidSyncService to work with the existing
/// SolidItemRepository implementation without modifications to either component.
class SolidItemRdfRepositoryAdapter implements RdfRepository {
  final ItemRepository _itemRepository;
  final ContextLogger _logger;

  SolidItemRdfRepositoryAdapter({
    required ItemRepository itemRepository,
    required LocalStorageService storage,
    LoggerService? loggerService,
  }) : _itemRepository = itemRepository,
       _logger = (loggerService ?? LoggerService()).createLogger(
         'SolidItemRdfRepositoryAdapter',
       );

  @override
  List<Object> getAllSyncableObjects() {
    _logger.debug('Getting all syncable objects');
    final items = _itemRepository.getAllItems();
    _logger.debug('Retrieved ${items.length} items for syncing');
    return items;
  }

  @override
  Future<int> mergeObjects(List<Object> objects) async {
    _logger.debug('Merging ${objects.length} objects from remote');
    int mergedCount = 0;

    // Filter and cast objects to Item
    final items = objects.whereType<Item>().toList();

    if (items.length != objects.length) {
      _logger.warning(
        'Some objects could not be cast to Item (${objects.length - items.length}/${objects.length})',
      );
    }

    if (items.isNotEmpty) {
      await _itemRepository.mergeItems(items);
      mergedCount = items.length;
      _logger.debug('Merged $mergedCount items');
    }

    return mergedCount;
  }
}
