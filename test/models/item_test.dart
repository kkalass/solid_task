import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/models/item.dart';

void main() {
  group('Item', () {
    late Item item;
    const String clientId = 'client1';

    setUp(() {
      item = Item(text: 'Test item', lastModifiedBy: clientId);
    });

    test('constructor initializes properties correctly', () {
      expect(item.text, equals('Test item'));
      expect(item.lastModifiedBy, equals(clientId));
      expect(item.isDeleted, isFalse);
      expect(item.vectorClock, equals({clientId: 1}));
      expect(item.id, isNotEmpty);
      expect(item.createdAt, isNotNull);
    });

    test('incrementClock increases vector clock for the given client', () {
      // Initial state
      expect(item.vectorClock[clientId], equals(1));

      // Increment for same client
      item.incrementClock(clientId);
      expect(item.vectorClock[clientId], equals(2));

      // Increment for new client
      const String newClient = 'client2';
      item.incrementClock(newClient);
      expect(item.vectorClock[newClient], equals(1));
    });

    test('isNewerThan compares vector clocks correctly', () {
      // Create a new item with same vector clock
      final otherItem = Item(text: 'Other item', lastModifiedBy: clientId);
      expect(item.isNewerThan(otherItem), isFalse);
      expect(otherItem.isNewerThan(item), isFalse);

      // Increment client's clock to make it newer
      item.incrementClock(clientId);
      expect(item.isNewerThan(otherItem), isTrue);
      expect(otherItem.isNewerThan(item), isFalse);

      // Add new client to other item
      otherItem.incrementClock('client2');
      // Neither is strictly newer now (concurrent edits)
      expect(item.isNewerThan(otherItem), isFalse);
      expect(otherItem.isNewerThan(item), isFalse);
    });

    test(
      'merge combines vector clocks and updates fields if other item is newer',
      () {
        // Create another item with modifications
        final otherItem = Item(text: 'Updated text', lastModifiedBy: 'client2');
        otherItem.id = item.id; // Same item ID

        // Ursprünglicher Zustand vor dem Merge
        expect(item.text, equals('Test item'));
        expect(item.vectorClock, equals({clientId: 1}));
        expect(otherItem.vectorClock, equals({'client2': 1}));

        // Erster Merge
        item.merge(otherItem);

        // Nach dem ersten Merge - beide Vector Clocks kombiniert
        expect(item.vectorClock, equals({clientId: 1, 'client2': 1}));

        // Beim ersten Merge wird der Text aktualisiert, da client2 neu in der Vector Clock ist
        expect(item.text, equals('Updated text'));

        // Dann otherItem strikt neuer machen
        otherItem.incrementClock(
          'client2',
        ); // client1:2 auf otherItem vs client1:1 auf item
        otherItem.text = 'Definitely newer text';

        // Zweiter Merge
        item.merge(otherItem);

        // Text sollte aktualisiert werden, da otherItem strikt neuer ist
        expect(item.text, equals('Definitely newer text'));
        expect(item.vectorClock, equals({clientId: 1, 'client2': 2}));
      },
    );

    test('toJson serializes the item correctly', () {
      final json = item.toJson();

      expect(json['id'], equals(item.id));
      expect(json['text'], equals('Test item'));
      expect(json['createdAt'], equals(item.createdAt.toIso8601String()));
      expect(json['vectorClock'], equals({clientId: 1}));
      expect(json['isDeleted'], equals(false));
      expect(json['lastModifiedBy'], equals(clientId));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': 'test-id-123',
        'text': 'Deserialized item',
        'createdAt': DateTime.now().toIso8601String(),
        'vectorClock': {'client3': 5, 'client4': 2},
        'isDeleted': true,
        'lastModifiedBy': 'client3',
      };

      final deserializedItem = Item.fromJson(json);

      expect(deserializedItem.id, equals('test-id-123'));
      expect(deserializedItem.text, equals('Deserialized item'));
      expect(
        deserializedItem.vectorClock,
        equals({'client3': 5, 'client4': 2}),
      );
      expect(deserializedItem.isDeleted, isTrue);
      expect(deserializedItem.lastModifiedBy, equals('client3'));
    });
  });
}
