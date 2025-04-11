import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/storage/hive_storage_service.dart';

import '../../mocks/mock_temp_dir_path_provider.dart';

/// Integration test for HiveStorageService
///
/// These tests verify that the real storage implementation works correctly
/// with the actual Hive backend (not mocked).
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group('HiveStorageService Integration Test', () {
    late HiveStorageService storageService;
    late MockTempDirPathProvider mockPathProvider;

    setUp(() async {
      // Create isolated storage for each test
      // Set up a temporary directory for test data
      mockPathProvider = MockTempDirPathProvider(
        prefix: 'test_hive_storage_functional',
      );
      PathProviderPlatform.instance = mockPathProvider;

      // Create the storage service, letting it handle Hive initialization
      // and adapter registration
      storageService = await HiveStorageService.create();

      // Clear all items to start with a clean state
      final items = storageService.getAllItems();
      for (final item in items) {
        await storageService.deleteItem(item.id);
      }
    });

    tearDown(() async {
      // Clean up after each test
      await storageService.close();
      await mockPathProvider.cleanup();
    });

    test('should save and retrieve an item', () async {
      // Arrange
      final item = Item(text: 'Test Item', lastModifiedBy: 'testUser');

      // Act
      await storageService.saveItem(item);
      final retrievedItem = storageService.getItem(item.id);

      // Assert
      expect(retrievedItem, isNotNull);
      expect(retrievedItem!.text, equals('Test Item'));
      expect(retrievedItem.lastModifiedBy, equals('testUser'));
    });

    test('should delete an item', () async {
      // Arrange
      final item = Item(text: 'Item to delete', lastModifiedBy: 'testUser');
      await storageService.saveItem(item);

      // Act
      await storageService.deleteItem(item.id);
      final retrievedItem = storageService.getItem(item.id);

      // Assert
      expect(retrievedItem, isNull);
    });

    test('should get all items', () async {
      // Arrange
      final item1 = Item(text: 'Item 1', lastModifiedBy: 'testUser');
      await storageService.saveItem(item1);

      final item2 = Item(text: 'Item 2', lastModifiedBy: 'testUser');
      await storageService.saveItem(item2);

      // Act
      final allItems = storageService.getAllItems();

      // Assert
      expect(allItems.length, equals(2));
      expect(
        allItems.map((item) => item.text).toSet(),
        equals({'Item 1', 'Item 2'}),
      );
    });

    test('should emit updates via watchItems', () async {
      // Arrange - Get the stream first
      final stream = storageService.watchItems();
      final emissions = <List<Item>>[];
      final subscription = stream.listen(emissions.add);

      // Act - Add items one by one
      final item1 = Item(text: 'Item 1', lastModifiedBy: 'testUser');
      await storageService.saveItem(item1);

      final item2 = Item(text: 'Item 2', lastModifiedBy: 'testUser');
      await storageService.saveItem(item2);

      // Delete an item
      await storageService.deleteItem(item1.id);

      // Wait for events to propagate through the event loop
      // This is necessary because Hive's box listenable may not emit
      // synchronously but rather after microtasks are processed
      await _pumpEventQueue();

      // Clean up
      await subscription.cancel();

      // Assert - Should have 4 emissions: initial empty, item1, item1+item2, item2
      expect(emissions.length, equals(4));
      expect(emissions[0], isEmpty);
      expect(emissions[1].length, equals(1));
      expect(emissions[1][0].text, equals('Item 1'));
      expect(emissions[2].length, equals(2));
      expect(emissions[3].length, equals(1));
      expect(emissions[3][0].text, equals('Item 2'));
    });
  });
}

/// Helper function to process all pending events on the event queue
///
/// This function is important when testing reactive streams in Flutter, especially
/// with Hive's ValueListenable-based notifications. These notifications are often
/// scheduled as microtasks rather than being emitted synchronously.
///
/// By awaiting this function after operations that should trigger notifications,
/// we ensure that:
///
/// 1. All microtasks in the event queue are processed
/// 2. Any listeners to BoxEvent changes have a chance to execute
/// 3. Stream emissions have been delivered to our test listeners
///
/// This is not a "hack" but a standard way to test asynchronous event-based code
/// in Dart, analogous to how Flutter widget tests use the pump() method to process
/// the widget rendering pipeline.
Future<void> _pumpEventQueue() {
  final completer = Completer<void>();
  // Schedule a microtask that will complete the completer
  // This ensures we wait until all other microtasks scheduled
  // before this call have completed
  Future.microtask(() => completer.complete());
  return completer.future;
}
