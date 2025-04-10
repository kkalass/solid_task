import 'package:solid_task/models/item.dart';

/// Interface for local storage operations
abstract class LocalStorageService {
  /// Get all items in storage
  List<Item> getAllItems();

  /// Get an item by ID
  Item? getItem(String id);

  /// Save an item to storage
  Future<void> saveItem(Item item);

  /// Delete an item from storage
  Future<void> deleteItem(String id);

  /// Get a stream of changes to items
  Stream<List<Item>> watchItems();

  /// Close the storage service
  Future<void> close();
}
