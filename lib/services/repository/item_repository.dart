import 'package:solid_task/models/item.dart';

/// Repository interface for item operations
abstract class ItemRepository {
  /// Get all items
  List<Item> getAllItems();

  /// Get active (non-deleted) items
  List<Item> getActiveItems();

  /// Get an item by ID
  Item? getItem(String id);

  /// Create a new item
  Future<Item> createItem(String text, String creator);

  /// Update an existing item
  Future<Item> updateItem(Item item, String updater);

  /// Mark an item as deleted
  Future<void> deleteItem(String id, String deletedBy);

  /// Merge remote items with local items
  Future<void> mergeItems(List<Item> remoteItems);

  /// Get a stream of active items
  Stream<List<Item>> watchActiveItems();

  /// Get all items as a JSON serializable list
  List<Map<String, dynamic>> exportItems();

  /// Import items from JSON data
  Future<void> importItems(List<dynamic> jsonData);
}
