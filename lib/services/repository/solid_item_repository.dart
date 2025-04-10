import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';

/// Implementation of ItemRepository for SOLID with CRDT
class SolidItemRepository implements ItemRepository {
  final LocalStorageService _storage;
  final ContextLogger _logger;
  final BehaviorSubject<List<Item>> _itemsSubject =
      BehaviorSubject<List<Item>>();

  SolidItemRepository({
    required LocalStorageService storage,
    required ContextLogger logger,
  }) : _storage = storage,
       _logger = logger {
    _initializeStream();
  }

  void _initializeStream() {
    // FIXME KK - is it a really good idea to get all items here? Eventually we should
    // limit this somehow
    // Initialize the subject with current items
    _itemsSubject.add(getActiveItems());

    // Listen to storage changes and update the subject
    _storage.watchItems().listen((items) {
      final activeItems =
          items.where((item) => !item.isDeleted).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _itemsSubject.add(activeItems);
    });
  }

  @override
  List<Item> getAllItems() {
    return _storage.getAllItems();
  }

  @override
  List<Item> getActiveItems() {
    final items = _storage.getAllItems();
    return items.where((item) => !item.isDeleted).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Item? getItem(String id) {
    return _storage.getItem(id);
  }

  @override
  Future<Item> createItem(String text, String creator) async {
    final item = Item(text: text, lastModifiedBy: creator);
    // createItem should not increment the clock, as it is set in the constructor
    // item.incrementClock(creator);
    await _storage.saveItem(item);
    _logger.debug('Created item: ${item.id}');
    return item;
  }

  @override
  Future<Item> updateItem(Item item, String updater) async {
    item.lastModifiedBy = updater;
    item.incrementClock(updater);
    await _storage.saveItem(item);
    _logger.debug('Updated item: ${item.id}');
    return item;
  }

  @override
  Future<void> deleteItem(String id, String deletedBy) async {
    final item = _storage.getItem(id);
    if (item != null) {
      item.isDeleted = true;
      item.lastModifiedBy = deletedBy;
      item.incrementClock(deletedBy);
      await _storage.saveItem(item);
      _logger.debug('Marked item as deleted: $id');
    }
  }

  @override
  Future<void> mergeItems(List<Item> remoteItems) async {
    _logger.debug('Merging ${remoteItems.length} remote items');

    for (final remoteItem in remoteItems) {
      final localItem = _storage.getItem(remoteItem.id);
      if (localItem == null) {
        // New item from remote, just save it
        await _storage.saveItem(remoteItem);
        _logger.debug('Added new remote item: ${remoteItem.id}');
      } else {
        // Merge remote and local items using CRDT logic
        final mergedItem = _mergeCRDT(localItem, remoteItem);
        await _storage.saveItem(mergedItem);
        _logger.debug('Merged item: ${mergedItem.id}');
      }
    }
  }

  /// Merge two items using CRDT logic
  Item _mergeCRDT(Item local, Item remote) {
    // Create a new item with the same basic properties
    final mergedItem = Item(
      text: local.text,
      lastModifiedBy: local.lastModifiedBy,
    );

    // Copy properties that can't be set through constructor
    mergedItem.id = local.id;
    mergedItem.createdAt = local.createdAt;
    mergedItem.isDeleted = local.isDeleted;

    // Copy the vector clock from local
    mergedItem.vectorClock = Map.from(local.vectorClock);

    // Merge the remote vector clock
    for (final entry in remote.vectorClock.entries) {
      final nodeId = entry.key;
      final remoteClock = entry.value;

      if (!mergedItem.vectorClock.containsKey(nodeId) ||
          mergedItem.vectorClock[nodeId]! < remoteClock) {
        // Remote has newer updates from this node
        mergedItem.vectorClock[nodeId] = remoteClock;

        // If the remote clock is newer for the last modifier, take its values
        if (nodeId == remote.lastModifiedBy &&
            (!local.vectorClock.containsKey(nodeId) ||
                local.vectorClock[nodeId]! < remoteClock)) {
          mergedItem.text = remote.text;
          mergedItem.isDeleted = remote.isDeleted;
          mergedItem.lastModifiedBy = remote.lastModifiedBy;
        }
      }
    }

    return mergedItem;
  }

  @override
  Stream<List<Item>> watchActiveItems() {
    return _itemsSubject.stream;
  }

  @override
  List<Map<String, dynamic>> exportItems() {
    return getAllItems().map((item) => item.toJson()).toList();
  }

  @override
  Future<void> importItems(List<dynamic> jsonData) async {
    _logger.debug('Importing ${jsonData.length} items from JSON');
    final items = jsonData.map((json) => Item.fromJson(json)).toList();
    await mergeItems(items);
  }
}
