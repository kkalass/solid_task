// filepath: /Users/klaskalass/privat/solid_task/test/services/rdf/item_rdf_serializer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/item_rdf_serializer.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:solid_task/services/rdf/rdf_parser.dart';
import 'package:solid_task/services/rdf/rdf_serializer.dart';

void main() {
  late ItemRdfSerializer itemSerializer;
  late LoggerService loggerService;
  late RdfParser parser;
  late RdfSerializer serializer;
  late String contentType;
  setUp(() {
    loggerService = LoggerService();
    itemSerializer = ItemRdfSerializer(loggerService: loggerService);
    contentType = 'text/turtle';
    parser = RdfParserFactory(
      loggerService: loggerService,
    ).createParser(contentType: contentType);
    serializer = RdfSerializerFactory(
      loggerService: loggerService,
    ).createSerializer(contentType: contentType);
  });

  group('ItemRdfSerializer', () {
    test('should convert an item to RDF graph', () {
      // Arrange
      final item = Item(text: 'Test Item', lastModifiedBy: 'user1');
      item.id = 'test-id-123';
      item.createdAt = DateTime.parse('2025-04-14T10:00:00Z');
      item.vectorClock = {'user1': 1, 'user2': 2};
      item.isDeleted = false;

      // Act
      final (graph, prefixes) = itemSerializer.itemToRdf(item);

      // Assert
      expect(graph.triples, isNotEmpty);

      // Check basic item properties
      final itemUri = IriTerm('http://solidtask.org/tasks/${item.id}');

      final typeTriples = graph.findTriples(
        subject: itemUri,
        predicate: IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
      );
      expect(typeTriples.length, 1);
      expect(
        typeTriples.first.object,
        IriTerm('http://solidtask.org/ontology#Task'),
      );

      final textTriples = graph.findTriples(
        subject: itemUri,
        predicate: IriTerm('http://solidtask.org/ontology#text'),
      );
      expect(textTriples.length, 1);
      expect(textTriples.first.object, LiteralTerm.string('Test Item'));

      final deletedTriples = graph.findTriples(
        subject: itemUri,
        predicate: IriTerm('http://solidtask.org/ontology#isDeleted'),
      );
      expect(deletedTriples.length, 1);
      expect(
        deletedTriples.first.object,
        LiteralTerm(
          'false',
          datatype: IriTerm('http://www.w3.org/2001/XMLSchema#boolean'),
        ),
      );

      final createdTriples = graph.findTriples(
        subject: itemUri,
        predicate: IriTerm('http://purl.org/dc/terms/created'),
      );
      expect(createdTriples.length, 1);
      expect(
        createdTriples.first.object,
        LiteralTerm.typed('2025-04-14T10:00:00.000Z', 'dateTime'),
      );

      // Check vector clock
      final clockTriples = graph.findTriples(
        subject: itemUri,
        predicate: IriTerm('http://solidtask.org/ontology#vectorClock'),
      );
      expect(clockTriples.length, 2); // One for each clock entry
    });

    test('should serialize an item to Turtle format and parse it back', () {
      // Arrange
      final item = Item(text: 'Roundtrip Test', lastModifiedBy: 'user1');
      item.id = 'roundtrip-123';
      item.createdAt = DateTime.parse('2025-04-14T10:00:00Z');
      item.vectorClock = {'user1': 1, 'user2': 2};
      item.isDeleted = false;

      // Act
      final (rdf, prefixes) = itemSerializer.itemToRdf(item);
      final turtle = serializer.write(rdf, prefixes: prefixes);
      expect(turtle, isNotEmpty);

      // Parse the turtle back to a graph
      final graph = parser.parse(
        turtle,
        documentUrl: 'http://example.org/test',
      );

      // Convert the graph back to an item
      final itemUri = 'http://solidtask.org/tasks/${item.id}';
      final parsedItem = itemSerializer.rdfToItem(graph, itemUri);

      // Assert
      expect(parsedItem.id, item.id);
      expect(parsedItem.text, item.text);
      expect(parsedItem.isDeleted, item.isDeleted);
      expect(parsedItem.lastModifiedBy, item.lastModifiedBy);
      expect(
        parsedItem.createdAt.toIso8601String(),
        item.createdAt.toIso8601String(),
      );
      expect(parsedItem.vectorClock, item.vectorClock);
    });

    test('should handle items with special characters', () {
      // Arrange
      final item = Item(
        text: 'Test with "quotes" and \\ backslashes',
        lastModifiedBy: 'user1',
      );
      item.id = 'special-chars-123';

      // Act
      final (rdf, prefixes) = itemSerializer.itemToRdf(item);
      final turtle = serializer.write(rdf, prefixes: prefixes);
      final graph = parser.parse(
        turtle,
        documentUrl: 'http://example.org/test',
      );
      final itemUri = 'http://solidtask.org/tasks/${item.id}';
      final parsedItem = itemSerializer.rdfToItem(graph, itemUri);

      // Assert
      expect(parsedItem.text, item.text);
    });
  });
}
