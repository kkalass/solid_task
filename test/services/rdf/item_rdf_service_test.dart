import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/models/item_operation.dart';
import 'package:solid_task/services/rdf/item_rdf_service.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';

import '../../mocks/mock_logger.dart';

void main() {
  group('ItemRdfService', () {
    late ItemRdfService service;
    late MockLogger mockLogger;
    late Item testItem;
    late List<ItemOperation> testOperations;

    setUp(() {
      mockLogger = MockLogger();
      service = ItemRdfService(logger: mockLogger);

      // Create test item
      testItem = Item(text: 'Test Item', lastModifiedBy: 'testClient');
      testItem.id = 'test-item-123'; // Set explicit ID for predictable testing
      testItem.vectorClock = {'testClient': 1};

      // Create test operations
      testOperations = [
        ItemOperation(
          id: 'op1',
          timestamp: DateTime.parse('2025-04-10T12:00:00Z'),
          itemId: testItem.id,
          type: OperationType.create,
          clientId: 'testClient',
          vectorClock: {'testClient': 1},
          payload: {'text': 'Test Item'},
        ),
        ItemOperation(
          id: 'op2',
          timestamp: DateTime.parse('2025-04-10T13:00:00Z'),
          itemId: testItem.id,
          type: OperationType.update,
          clientId: 'testClient',
          vectorClock: {'testClient': 2},
          payload: {'text': 'Updated Item'},
          isSynced: true,
        ),
      ];
    });

    test('itemToRdf converts item and operations to RDF triples', () {
      final graph = service.itemToRdf(testItem, testOperations);

      // Verify the graph contains the expected triples
      final itemUri = 'http://solid-task.org/items/ns#item/${testItem.id}';

      // Check item properties
      final textTriples = graph.findTriples(
        subject: itemUri,
        predicate: 'http://solid-task.org/items/ns#text',
      );
      expect(textTriples.length, equals(1));
      expect(textTriples.first.object, equals(testItem.text));

      // Check vector clock
      final vectorClockTriples = graph.findTriples(
        subject: itemUri,
        predicate: 'http://solid-task.org/crdt/ns#vectorClock',
      );
      expect(vectorClockTriples.length, equals(1));
      final Map<String, dynamic> parsedClock = jsonDecode(vectorClockTriples.first.object);
      expect(parsedClock, equals({'testClient': 1}));

      // Check operations
      final opTriples = graph.findTriples(
        subject: itemUri,
        predicate: 'http://solid-task.org/crdt/ns#hasOperation',
      );
      expect(opTriples.length, equals(2));

      // Verify first operation
      final opUri1 = 'http://solid-task.org/crdt/ns#operation/op1';
      final typeTriples1 = graph.findTriples(
        subject: opUri1,
        predicate: 'http://solid-task.org/crdt/ns#type',
      );
      expect(typeTriples1.first.object, equals('create'));

      // Verify second operation
      final opUri2 = 'http://solid-task.org/crdt/ns#operation/op2';
      final typeTriples2 = graph.findTriples(
        subject: opUri2,
        predicate: 'http://solid-task.org/crdt/ns#type',
      );
      expect(typeTriples2.first.object, equals('update'));

      // Check sync status
      final syncTriples = graph.findTriples(
        subject: opUri2,
        predicate: 'http://solid-task.org/crdt/ns#isSynced',
      );
      expect(syncTriples.first.object, equals('true'));
    });

    test('rdfToItem converts RDF triples back to item and operations', () {
      // First convert to RDF
      final graph = service.itemToRdf(testItem, testOperations);

      // Then convert back to item and operations
      final (resultItem, resultOperations) = service.rdfToItem(graph, testItem.id);

      // Verify the item
      expect(resultItem.id, equals(testItem.id));
      expect(resultItem.text, equals(testItem.text));
      expect(resultItem.lastModifiedBy, equals(testItem.lastModifiedBy));
      expect(resultItem.vectorClock, equals(testItem.vectorClock));
      expect(resultItem.isDeleted, equals(testItem.isDeleted));

      // Verify the operations
      expect(resultOperations.length, equals(2));
      
      // Sort to ensure consistent order for testing
      resultOperations.sort((a, b) => a.id.compareTo(b.id));
      
      // Check first operation
      expect(resultOperations[0].id, equals('op1'));
      expect(resultOperations[0].type, equals(OperationType.create));
      expect(resultOperations[0].clientId, equals('testClient'));
      expect(resultOperations[0].vectorClock, equals({'testClient': 1}));
      expect(resultOperations[0].payload, equals({'text': 'Test Item'}));
      
      // Check second operation
      expect(resultOperations[1].id, equals('op2'));
      expect(resultOperations[1].type, equals(OperationType.update));
      expect(resultOperations[1].vectorClock, equals({'testClient': 2}));
      expect(resultOperations[1].payload, equals({'text': 'Updated Item'}));
      expect(resultOperations[1].isSynced, isTrue);
    });

    test('itemToTurtle generates valid Turtle syntax', () {
      final turtle = service.itemToTurtle(testItem, testOperations);

      // Basic checks for Turtle format
      expect(turtle, contains('@prefix'));
      // Check for prefixed format, not full URI
      expect(turtle, contains('item:item/${testItem.id}'));
      expect(turtle, contains('item:text'));
      expect(turtle, contains('"${testItem.text}"'));
      expect(turtle, contains('crdt:operation/op1'));
    });

    test('rdfToItem throws FormatException when required properties are missing', () {
      // Create a graph missing required properties
      final incompleteGraph = RdfGraph();
      
      // Missing the text property
      incompleteGraph.addTriple(Triple(
        'http://solid-task.org/items/ns#item/${testItem.id}',
        'http://solid-task.org/items/ns#lastModifiedBy',
        'testClient',
      ));

      expect(
        () => service.rdfToItem(incompleteGraph, testItem.id),
        throwsA(isA<FormatException>()),
      );
    });
  });
}