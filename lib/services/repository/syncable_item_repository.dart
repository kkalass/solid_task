import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/sync/sync_manager.dart';

/// A decorator for ItemRepository that automatically triggers sync operations
/// when data is modified while maintaining the original repository's behavior.
class SyncableItemRepository implements ItemRepository {
  final ItemRepository _repository;
  final SyncManager _syncManager;

  /// Creates a decorator around a repository that triggers sync
  /// operations on data modifications
  SyncableItemRepository(this._repository, this._syncManager);

  @override
  List<Item> getAllItems() => _repository.getAllItems();

  @override
  List<Item> getActiveItems() => _repository.getActiveItems();

  @override
  Item? getItem(String id) => _repository.getItem(id);

  @override
  Future<Item> createItem(String text, String creator) async {
    final result = await _repository.createItem(text, creator);
    _syncManager.requestSync();
    return result;
  }

  @override
  Future<Item> updateItem(Item item, String updater) async {
    final result = await _repository.updateItem(item, updater);
    _syncManager.requestSync();
    return result;
  }

  @override
  Future<void> deleteItem(String id, String deletedBy) async {
    await _repository.deleteItem(id, deletedBy);
    _syncManager.requestSync();
  }

  @override
  Future<void> mergeItems(List<Item> remoteItems) =>
      _repository.mergeItems(remoteItems);

  @override
  Stream<List<Item>> watchActiveItems() => _repository.watchActiveItems();

  @override
  List<Map<String, dynamic>> exportItems() => _repository.exportItems();

  @override
  Future<void> importItems(List<dynamic> jsonData) =>
      _repository.importItems(jsonData);
}
