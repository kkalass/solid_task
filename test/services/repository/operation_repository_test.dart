import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/models/item_operation.dart';
import 'package:solid_task/services/repository/operation_repository.dart';
import 'package:solid_task/services/storage/hive_backend.dart';

import '../../mocks/mock_box.dart';
import '../../mocks/mock_logger.dart';
import '../../mocks/mock_hive_backend.dart';

void main() {
  group('OperationRepository', () {
    late MockBox mockBox;
    late MockLogger mockLogger;
    late MockHiveBackend mockHiveBackend;
    late OperationRepository repository;

    setUp(() async {
      mockBox = MockBox();
      mockLogger = MockLogger();
      mockHiveBackend = MockHiveBackend();
      
      // Mock HiveBackend methods
      when(mockHiveBackend.initFlutter(any)).thenAnswer((_) => Future.value());
      when(mockHiveBackend.openBox(any)).thenAnswer((_) => Future.value(mockBox));
      
      // Setup mock box.watch() to return a stream that never emits
      when(mockBox.watch()).thenAnswer((_) => Stream.empty());
      when(mockBox.close()).thenAnswer((_) => Future.value());
      when(mockHiveBackend.closeBoxes()).thenAnswer((_) => Future.value());
      
      // Create repository with private constructor for testing
      repository = await OperationRepository.create(
        hiveBackend: mockHiveBackend,
        loggerService: MockLoggerService(),
      );
    });

    test('getAllOperations returns operations from box values', () {
      // Setup mock data
      final op1 = ItemOperation(
        id: 'op1',
        itemId: 'item1',
        type: OperationType.create,
        clientId: 'client1',
        vectorClock: {'client1': 1},
        payload: {'text': 'Test Item'},
      );

      final op2 = ItemOperation(
        id: 'op2',
        itemId: 'item1',
        type: OperationType.update,
        clientId: 'client1',
        vectorClock: {'client1': 2},
        payload: {'text': 'Updated Text'},
      );

      // Mock box.values to return the serialized operations
      when(mockBox.values).thenReturn([
        op1.toJson(),
        op2.toJson(),
      ]);

      // Test
      final operations = repository.getAllOperations();

      // Verify
      expect(operations.length, equals(2));
      expect(operations[0].id, equals('op1'));
      expect(operations[0].type, equals(OperationType.create));
      expect(operations[1].id, equals('op2'));
      expect(operations[1].type, equals(OperationType.update));
    });

    test('getOperationsForItem filters by itemId', () {
      // Setup mock operations for two different items
      final op1 = ItemOperation(
        id: 'op1',
        itemId: 'item1',
        type: OperationType.create,
        clientId: 'client1',
        vectorClock: {'client1': 1},
        payload: {'text': 'Item 1'},
      );

      final op2 = ItemOperation(
        id: 'op2',
        itemId: 'item2',
        type: OperationType.create,
        clientId: 'client1',
        vectorClock: {'client1': 1},
        payload: {'text': 'Item 2'},
      );

      final op3 = ItemOperation(
        id: 'op3',
        itemId: 'item1',
        type: OperationType.update,
        clientId: 'client1',
        vectorClock: {'client1': 2},
        payload: {'text': 'Updated Item 1'},
      );

      // Mock box.values
      when(mockBox.values).thenReturn([
        op1.toJson(),
        op2.toJson(),
        op3.toJson(),
      ]);

      // Test
      final item1Operations = repository.getOperationsForItem('item1');
      final item2Operations = repository.getOperationsForItem('item2');

      // Verify
      expect(item1Operations.length, equals(2));
      expect(item1Operations[0].id, equals('op1'));
      expect(item1Operations[1].id, equals('op3'));

      expect(item2Operations.length, equals(1));
      expect(item2Operations[0].id, equals('op2'));
    });

    test('getUnsyncedOperationsForItem filters by itemId and sync state', () {
      // Setup mock operations with different sync states
      final op1 = ItemOperation(
        id: 'op1',
        itemId: 'item1',
        type: OperationType.create,
        clientId: 'client1',
        vectorClock: {'client1': 1},
        payload: {'text': 'Item 1'},
        isSynced: true, // synced
      );

      final op2 = ItemOperation(
        id: 'op2',
        itemId: 'item1',
        type: OperationType.update,
        clientId: 'client1',
        vectorClock: {'client1': 2},
        payload: {'text': 'Updated Item 1'},
        isSynced: false, // not synced
      );

      // Mock box.values
      when(mockBox.values).thenReturn([
        op1.toJson(),
        op2.toJson(),
      ]);

      // Test
      final unsyncedOperations = repository.getUnsyncedOperationsForItem('item1');

      // Verify
      expect(unsyncedOperations.length, equals(1));
      expect(unsyncedOperations[0].id, equals('op2'));
      expect(unsyncedOperations[0].isSynced, isFalse);
    });

    test('saveOperation puts operation into box', () async {
      // Setup
      final operation = ItemOperation(
        id: 'test-op',
        itemId: 'item1',
        type: OperationType.create,
        clientId: 'client1',
        vectorClock: {'client1': 1},
        payload: {'text': 'Test Item'},
      );

      // Mock box.put
      when(mockBox.put(any, any)).thenAnswer((_) => Future.value());

      // Test
      await repository.saveOperation(operation);

      // Verify
      verify(mockBox.put('test-op', operation.toJson())).called(1);
    });

    test('markAsSynced updates operations sync status', () async {
      // Setup
      final operations = [
        ItemOperation(
          id: 'op1',
          itemId: 'item1',
          type: OperationType.create,
          clientId: 'client1',
          vectorClock: {'client1': 1},
          payload: {'text': 'Item 1'},
          isSynced: false,
        ),
        ItemOperation(
          id: 'op2',
          itemId: 'item1',
          type: OperationType.update,
          clientId: 'client1',
          vectorClock: {'client1': 2},
          payload: {'text': 'Updated Item 1'},
          isSynced: false,
        ),
      ];

      // Mock box.put
      when(mockBox.put(any, any)).thenAnswer((_) => Future.value());

      // Test
      await repository.markAsSynced(operations);

      // Verify each operation was updated and saved
      for (final op in operations) {
        expect(op.isSynced, isTrue);
        verify(mockBox.put(op.id, op.toJson())).called(1);
      }
    });

    test('cleanupOperationsForDeletedItems removes operations for deleted items', () async {
      // Setup operations for multiple items
      final op1 = ItemOperation(
        id: 'op1',
        itemId: 'item1',
        type: OperationType.create,
        clientId: 'client1',
        vectorClock: {'client1': 1},
        payload: {'text': 'Item 1'},
        isSynced: true,
      );

      final op2 = ItemOperation(
        id: 'op2',
        itemId: 'item2',
        type: OperationType.create,
        clientId: 'client1',
        vectorClock: {'client1': 1},
        payload: {'text': 'Item 2'},
        isSynced: true,
      );

      // Mock box methods
      when(mockBox.values).thenReturn([
        op1.toJson(),
        op2.toJson(),
      ]);
      when(mockBox.delete(any)).thenAnswer((_) => Future.value());

      // Test - only item1 is active, item2 is deleted
      await repository.cleanupOperationsForDeletedItems(['item1']);

      // Verify - operations for item2 were deleted
      verify(mockBox.delete('op2')).called(1);
      // Verify operations for item1 were preserved
      verifyNever(mockBox.delete('op1'));
    });

    test('watchOperations emits operations when box changes', () async {
      // Setup initial operations
      final initialOp = ItemOperation(
        id: 'op1',
        itemId: 'item1',
        type: OperationType.create,
        clientId: 'client1',
        vectorClock: {'client1': 1},
        payload: {'text': 'Initial Item'},
      );

      // Mock box methods
      when(mockBox.values).thenReturn([initialOp.toJson()]);
      
      // Create a controller to simulate watch events
      final controller = StreamController<BoxEvent>();
      when(mockBox.watch()).thenAnswer((_) => controller.stream);

      // Use the already created repository
      final watchRepo = repository;
      
      // Collect emitted operations for verification
      final emittedOperations = <List<ItemOperation>>[];
      final subscription = watchRepo.watchOperations().listen(
        (operations) => emittedOperations.add(operations),
        onError: (e) => fail('Stream error: $e'),
      );
      
      // Wait for initial operations to be emitted
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Verify initial emission
      expect(emittedOperations.isNotEmpty, isTrue, reason: 'Should have received initial operations');
      expect(emittedOperations.first.length, 1, reason: 'Should have one initial operation');
      expect(emittedOperations.first[0].id, 'op1', reason: 'Initial operation ID should match');
      
      // Now simulate a change - add a new operation
      final newOp = ItemOperation(
        id: 'op2',
        itemId: 'item1',
        type: OperationType.update,
        clientId: 'client1',
        vectorClock: {'client1': 2},
        payload: {'text': 'Updated Item'},
      );
      
      // Update mock values to include both operations
      when(mockBox.values).thenReturn([
        initialOp.toJson(),
        newOp.toJson(),
      ]);
      
      // Trigger the box event
      controller.add(BoxEvent('op2', newOp.toJson(), false));
      
      // Allow more time for the event to be processed
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Verify that we received the updated operations
      expect(emittedOperations.length, greaterThan(1), 
             reason: 'Should receive updated operations after box event');
      
      // Get the latest emission
      final latestEmission = emittedOperations.last;
      expect(latestEmission.length, 2, reason: 'Latest emission should have 2 operations');
      expect(latestEmission.map((op) => op.id).contains('op1'), isTrue, 
             reason: 'Latest emission should contain op1');
      expect(latestEmission.map((op) => op.id).contains('op2'), isTrue, 
             reason: 'Latest emission should contain op2');
      
      // Clean up
      await subscription.cancel();
      await controller.close();
      await watchRepo.close();
    });
  });
}