// filepath: /Users/klaskalass/privat/solid_task/test/services/rdf/item_rdf_serializer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/item_rdf_mapper.dart';
import 'package:solid_task/services/rdf/item_rdf_serializer.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:solid_task/services/rdf/rdf_type_converter.dart';
import 'package:solid_task/services/rdf/task_ontology_constants.dart';

void main() {
  late LoggerService loggerService;
  late RdfTypeConverter typeConverter;
  late ItemRdfMapper mapper;
  late ItemRdfSerializer serializer;

  setUp(() {
    loggerService = LoggerService();
    typeConverter = RdfTypeConverter(loggerService: loggerService);
    mapper = ItemRdfMapper(
      loggerService: loggerService,
      typeConverter: typeConverter,
    );
    serializer = ItemRdfSerializer(
      loggerService: loggerService,
      mapper: mapper,
    );
  });

  group('ItemRdfSerializer', () {
    test('should convert item to RDF and back', () {
      // Create a test item
      final originalItem = Item(text: 'Test item', lastModifiedBy: 'test-user');
      originalItem.id = 'test-id-123';
      originalItem.isDeleted = false;
      originalItem.vectorClock = {'user1': 1, 'user2': 2};

      // Convert to RDF
      final graph = serializer.itemToRdf(originalItem);

      // Basic verification
      expect(graph.isEmpty, isFalse);

      // Find triples by subject
      final itemUri = TaskOntologyConstants.makeTaskUri(originalItem.id);
      final subjectIri = IriTerm(itemUri);

      // Verify text property
      final textTriples = graph.findTriples(
        subject: subjectIri,
        predicate: TaskOntologyConstants.textIri,
      );
      expect(textTriples.length, equals(1));
      expect(textTriples.first.object, isA<LiteralTerm>());
      expect(
        (textTriples.first.object as LiteralTerm).value,
        equals('Test item'),
      );

      // Convert back to item
      final reconstructedItem = serializer.rdfToItem(graph, itemUri);

      // Verify all properties were preserved
      expect(reconstructedItem.id, equals(originalItem.id));
      expect(reconstructedItem.text, equals(originalItem.text));
      expect(
        reconstructedItem.lastModifiedBy,
        equals(originalItem.lastModifiedBy),
      );
      expect(reconstructedItem.isDeleted, equals(originalItem.isDeleted));
      expect(reconstructedItem.vectorClock, equals(originalItem.vectorClock));
    });

    test('should convert item to string and back', () {
      // Create a test item
      final originalItem = Item(
        text: 'Test item with string serialization',
        lastModifiedBy: 'test-user-string',
      );
      originalItem.id = 'test-id-string-456';
      originalItem.isDeleted = true;
      originalItem.vectorClock = {'user3': 3, 'user4': 4};

      // Convert to string
      final rdfString = serializer.itemToString(originalItem);

      // Verify basic content
      expect(rdfString, isNotEmpty);
      expect(rdfString, contains('@prefix'));
      expect(rdfString, contains('task:text'));

      // Convert back to item
      final reconstructedItem = serializer.itemFromString(
        rdfString,
        originalItem.id,
      );

      // Verify all properties were preserved
      expect(reconstructedItem.id, equals(originalItem.id));
      expect(reconstructedItem.text, equals(originalItem.text));
      expect(
        reconstructedItem.lastModifiedBy,
        equals(originalItem.lastModifiedBy),
      );
      expect(reconstructedItem.isDeleted, equals(originalItem.isDeleted));
      expect(reconstructedItem.vectorClock, equals(originalItem.vectorClock));
    });

    test('should handle items with special characters', () {
      // Arrange
      final item = Item(
        text: 'Test with "quotes" and \\ backslashes',
        lastModifiedBy: 'user1',
      );
      item.id = 'special-chars-123';

      // Act
      final turtle = serializer.itemToString(item);
      final parsedItem = serializer.itemFromString(turtle, item.id);

      // Assert
      expect(parsedItem.text, item.text);
    });

    test('should handle items with non-ASCII characters', () {
      // Arrange
      final item = Item(
        text: 'Test with non-ASCII: ñ, ü, é',
        lastModifiedBy: 'user2',
      );
      item.id = 'non-ascii-456';

      // Act
      final turtle = serializer.itemToString(item);
      final parsedItem = serializer.itemFromString(turtle, item.id);

      // Assert
      expect(parsedItem.text, item.text);
    });

    test('should handle RDF parsing errors', () {
      // Invalid missing text property
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm(TaskOntologyConstants.makeTaskUri('invalid')),
            IriTerm('http://purl.org/dc/terms/creator'),
            LiteralTerm.string('user'),
          ),
        ],
      );

      // Should throw because text property is missing
      expect(
        () => serializer.rdfToItem(
          graph,
          TaskOntologyConstants.makeTaskUri('invalid'),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
