import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/models/item_operation.dart';

void main() {
  group('ItemOperation', () {
    late Item item;
    const String clientId = 'client1';

    setUp(() {
      item = Item(text: 'Test item', lastModifiedBy: clientId);
    });

    test('constructor initializes properties correctly', () {
      final operation = ItemOperation(
        itemId: item.id,
        type: OperationType.create,
        clientId: clientId,
        vectorClock: {clientId: 1},
        payload: {'text': 'Test item'},
      );

      expect(operation.itemId, equals(item.id));
      expect(operation.type, equals(OperationType.create));
      expect(operation.clientId, equals(clientId));
      expect(operation.vectorClock, equals({clientId: 1}));
      expect(operation.payload, equals({'text': 'Test item'}));
      expect(operation.isSynced, isFalse);
      expect(operation.id, isNotEmpty);
      expect(operation.timestamp, isNotNull);
    });

    test('factory constructors create operations with correct types and data', () {
      final createOp = ItemOperation.create(item);
      expect(createOp.type, equals(OperationType.create));
      expect(createOp.itemId, equals(item.id));
      expect(createOp.clientId, equals(clientId));
      expect(createOp.vectorClock, equals({clientId: 1}));
      expect(createOp.payload, equals({'text': 'Test item'}));

      // Update item and create update operation
      item.text = 'Updated text';
      item.incrementClock(clientId);
      final updateOp = ItemOperation.update(item);
      expect(updateOp.type, equals(OperationType.update));
      expect(updateOp.vectorClock, equals({clientId: 2}));
      expect(updateOp.payload, equals({'text': 'Updated text'}));

      // Create delete operation
      final deleteOp = ItemOperation.delete(item);
      expect(deleteOp.type, equals(OperationType.delete));
      expect(deleteOp.payload, equals({}));
    });

    test('applyTo creates new item when applying a create operation', () {
      final operation = ItemOperation.create(item);
      final resultItem = operation.applyTo(null);

      expect(resultItem.id, equals(item.id));
      expect(resultItem.text, equals(item.text));
      expect(resultItem.vectorClock, equals(item.vectorClock));
    });

    test('applyTo updates existing item when operation is newer', () {
      // Create base item
      final baseItem = Item(text: 'Original text', lastModifiedBy: 'client2');
      baseItem.id = item.id; // Same ID as the test item
      baseItem.vectorClock = {'client2': 1};

      // Create operation with newer clock
      final operation = ItemOperation(
        itemId: item.id,
        type: OperationType.update,
        clientId: clientId,
        vectorClock: {clientId: 2},
        payload: {'text': 'New text from operation'},
      );

      // Apply operation
      final resultItem = operation.applyTo(baseItem);

      // Should update the text because the operation has newer information
      expect(resultItem.text, equals('New text from operation'));
      // Should merge vector clocks
      expect(resultItem.vectorClock, equals({'client2': 1, clientId: 2}));
      // Should update lastModifiedBy
      expect(resultItem.lastModifiedBy, equals(clientId));
    });

    test('applyTo does not update item content when operation is older', () {
      // Create base item with newer clock
      final baseItem = Item(text: 'Newer text', lastModifiedBy: clientId);
      baseItem.id = item.id;
      baseItem.vectorClock = {clientId: 3}; // Higher clock value

      // Create operation with older clock
      final operation = ItemOperation(
        itemId: item.id,
        type: OperationType.update,
        clientId: clientId,
        vectorClock: {clientId: 1}, // Lower clock value
        payload: {'text': 'Older text from operation'},
      );

      // Apply operation
      final resultItem = operation.applyTo(baseItem);

      // Should not update the text because the item has newer information
      expect(resultItem.text, equals('Newer text'));
      // Vector clock should remain unchanged
      expect(resultItem.vectorClock, equals({clientId: 3}));
    });

    test('applyTo marks item as deleted when applying a delete operation', () {
      // Create a non-deleted item
      final baseItem = Item(text: 'Item to delete', lastModifiedBy: clientId);
      baseItem.id = item.id;
      baseItem.isDeleted = false;

      // Create delete operation
      final operation = ItemOperation(
        itemId: item.id,
        type: OperationType.delete,
        clientId: clientId,
        vectorClock: {clientId: 2}, // Newer clock
        payload: {},
      );

      // Apply operation
      final resultItem = operation.applyTo(baseItem);

      // Should mark as deleted
      expect(resultItem.isDeleted, isTrue);
    });

    test('toJson and fromJson correctly serialize and deserialize operations', () {
      final operation = ItemOperation(
        id: 'test-op-123',
        timestamp: DateTime.parse('2025-04-11T12:00:00Z'),
        itemId: 'item-123',
        type: OperationType.update,
        clientId: 'client3',
        vectorClock: {'client3': 5, 'client4': 2},
        payload: {'text': 'Serialized operation'},
        isSynced: true,
      );

      final json = operation.toJson();
      final deserializedOp = ItemOperation.fromJson(json);

      expect(deserializedOp.id, equals('test-op-123'));
      expect(deserializedOp.timestamp.toIso8601String(), equals('2025-04-11T12:00:00.000Z'));
      expect(deserializedOp.itemId, equals('item-123'));
      expect(deserializedOp.type, equals(OperationType.update));
      expect(deserializedOp.clientId, equals('client3'));
      expect(deserializedOp.vectorClock, equals({'client3': 5, 'client4': 2}));
      expect(deserializedOp.payload, equals({'text': 'Serialized operation'}));
      expect(deserializedOp.isSynced, isTrue);
    });

    test('fromJson throws exception for unknown operation type', () {
      final json = {
        'id': 'test-op-123',
        'timestamp': DateTime.now().toIso8601String(),
        'itemId': 'item-123',
        'type': 'unknown',
        'clientId': 'client1',
        'vectorClock': {'client1': 1},
        'payload': {},
      };

      expect(() => ItemOperation.fromJson(json), throwsA(isA<FormatException>()));
    });
  });
}