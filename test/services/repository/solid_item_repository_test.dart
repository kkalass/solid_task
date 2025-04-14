import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/repository/operation_repository.dart';
import 'package:solid_task/services/repository/solid_item_repository.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';

@GenerateNiceMocks([
  MockSpec<LocalStorageService>(),
  MockSpec<LoggerService>(),
  MockSpec<ContextLogger>(),
  MockSpec<OperationRepository>(),
])
import 'solid_item_repository_test.mocks.dart';

void main() {
  group('SolidItemRepository', () {
    late MockLocalStorageService mockStorage;
    late MockContextLogger mockLogger;
    late MockOperationRepository mockOperationRepository;
    late SolidItemRepository repository;

    setUp(() {
      mockStorage = MockLocalStorageService();
      mockLogger = MockContextLogger();
      mockOperationRepository = MockOperationRepository();

      // Reset Mockito state for all mocks
      reset(mockStorage);
      reset(mockLogger);
      reset(mockOperationRepository);

      // Setup the stream for watchItems
      when(mockStorage.watchItems()).thenAnswer((_) => Stream.value([]));

      repository = SolidItemRepository(
        storage: mockStorage,
        logger: mockLogger,
        operationRepository: mockOperationRepository,
      );
    });

    test('getAllItems delegates to storage service', () {
      // Setup
      final items = [
        Item(text: 'Item 1', lastModifiedBy: 'user1'),
        Item(text: 'Item 2', lastModifiedBy: 'user2'),
      ];
      when(mockStorage.getAllItems()).thenReturn(items);
      // Execute
      final result = repository.getAllItems();

      // Verify
      expect(result, equals(items));
      // Verify that the storage service was called - it was already called once
      // in the setup method via the constructor, so we expect it to be called
      // twice by now.
      verify(mockStorage.getAllItems()).called(2);
    });

    test('getActiveItems filters out deleted items and sorts by date', () {
      // Setup
      final item1 = Item(text: 'Item 1', lastModifiedBy: 'user1');
      final item2 = Item(text: 'Item 2', lastModifiedBy: 'user2')
        ..isDeleted = true;
      final item3 = Item(text: 'Item 3', lastModifiedBy: 'user1');

      // Force createdAt to be in a specific order for testing sort
      item1.createdAt = DateTime(2022, 1, 1);
      item3.createdAt = DateTime(2022, 1, 2); // Newer, should come first

      when(mockStorage.getAllItems()).thenReturn([item1, item2, item3]);

      // Execute
      final result = repository.getActiveItems();

      // Verify
      expect(result.length, 2);
      expect(result[0], equals(item3)); // Newer item first
      expect(result[1], equals(item1)); // Older item second
      expect(result.contains(item2), isFalse); // Deleted item filtered out
    });

    test('getItem delegates to storage service', () {
      // Setup
      final item = Item(text: 'Test Item', lastModifiedBy: 'user1');
      when(mockStorage.getItem('item-id')).thenReturn(item);
      when(mockStorage.getItem('non-existent')).thenReturn(null);

      // Execute & Verify
      expect(repository.getItem('item-id'), equals(item));
      expect(repository.getItem('non-existent'), isNull);
    });

    test('createItem creates a new item and saves it', () async {
      // Setup
      when(mockStorage.saveItem(any)).thenAnswer((_) async {});

      // Execute
      final item = await repository.createItem('New item', 'creator-id');

      // Verify
      expect(item.text, equals('New item'));
      expect(item.lastModifiedBy, equals('creator-id'));
      expect(item.vectorClock['creator-id'], equals(1));
      expect(item.isDeleted, isFalse);
      verify(mockStorage.saveItem(item)).called(1);
      verify(mockLogger.debug(any)).called(1);
    });

    test('updateItem updates and saves an item', () async {
      // Setup
      final item = Item(text: 'Original text', lastModifiedBy: 'user1');
      when(mockStorage.saveItem(any)).thenAnswer((_) async {});

      // Execute
      item.text = 'Updated text';
      final updatedItem = await repository.updateItem(item, 'updater-id');

      // Verify
      expect(updatedItem.text, equals('Updated text'));
      expect(updatedItem.lastModifiedBy, equals('updater-id'));
      expect(updatedItem.vectorClock['updater-id'], equals(1));
      verify(mockStorage.saveItem(item)).called(1);
      verify(mockLogger.debug(any)).called(1);
    });

    test('deleteItem marks an item as deleted', () async {
      // Setup
      final itemId = 'item-123';
      final item = Item(text: 'To be deleted', lastModifiedBy: 'user1');
      when(mockStorage.getItem(itemId)).thenReturn(item);
      when(mockStorage.saveItem(any)).thenAnswer((_) async {});

      // Execute
      await repository.deleteItem(itemId, 'deleter-id');

      // Verify
      expect(item.isDeleted, isTrue);
      expect(item.lastModifiedBy, equals('deleter-id'));
      expect(item.vectorClock['deleter-id'], equals(1));
      verify(mockStorage.saveItem(item)).called(1);
      verify(mockLogger.debug(any)).called(1);
    });

    test('mergeItems handles both new and existing items', () async {
      // Setup
      final localItem = Item(text: 'Local version', lastModifiedBy: 'local');
      localItem.id = 'existing-id';

      final remoteExistingItem = Item(
        text: 'Remote version',
        lastModifiedBy: 'remote',
      );
      remoteExistingItem.id = 'existing-id';

      final remoteNewItem = Item(
        text: 'New remote item',
        lastModifiedBy: 'remote',
      );
      remoteNewItem.id = 'new-id';

      when(mockStorage.getItem('existing-id')).thenReturn(localItem);
      when(mockStorage.getItem('new-id')).thenReturn(null);
      when(mockStorage.saveItem(any)).thenAnswer((_) async {});

      // Execute
      await repository.mergeItems([remoteExistingItem, remoteNewItem]);

      // Verify
      // Should have attempted to get both items
      verify(mockStorage.getItem('existing-id')).called(1);
      verify(mockStorage.getItem('new-id')).called(1);

      // Should have saved two items (merged and new)
      verify(mockStorage.saveItem(any)).called(2);
      verify(
        mockLogger.debug(any),
      ).called(3); // Including the initial debug message
    });

    test('exportItems converts all items to JSON', () {
      // Setup
      final item1 = Item(text: 'Item 1', lastModifiedBy: 'user1');
      final item2 = Item(text: 'Item 2', lastModifiedBy: 'user2');
      when(mockStorage.getAllItems()).thenReturn([item1, item2]);

      // Execute
      final jsonList = repository.exportItems();

      // Verify
      expect(jsonList.length, 2);
      expect(jsonList[0]['text'], 'Item 1');
      expect(jsonList[1]['text'], 'Item 2');
    });

    test('importItems converts JSON to items and merges them', () async {
      // Setup
      final jsonData = [
        {
          'id': 'item-1',
          'text': 'Item 1',
          'createdAt': DateTime.now().toIso8601String(),
          'vectorClock': {'user1': 1},
          'isDeleted': false,
          'lastModifiedBy': 'user1',
        },
        {
          'id': 'item-2',
          'text': 'Item 2',
          'createdAt': DateTime.now().toIso8601String(),
          'vectorClock': {'user2': 1},
          'isDeleted': false,
          'lastModifiedBy': 'user2',
        },
      ];

      // Mock the storage responses for merge
      when(mockStorage.getItem(any)).thenReturn(null);
      when(mockStorage.saveItem(any)).thenAnswer((_) async {});

      // Execute
      await repository.importItems(jsonData);

      // Verify
      // Each item should be checked and saved (2 items)
      verify(mockStorage.getItem(any)).called(2);
      verify(mockStorage.saveItem(any)).called(2);
    });
  });
}
