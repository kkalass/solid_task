import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/mapping/item_rdf_mapper.dart';
import 'package:solid_task/services/rdf/mapping/rdf_mapper_registry.dart';
import 'package:solid_task/services/rdf/mapping/rdf_mapper_service.dart';
import 'package:solid_task/services/rdf/mapping/rdf_type_converter.dart';
import 'package:solid_task/services/rdf/rdf_parser.dart';
import 'package:solid_task/services/rdf/rdf_serializer.dart';
import 'package:solid_task/services/rdf/task_ontology_constants.dart';

void main() {
  late LoggerService loggerService;
  late RdfTypeConverter typeConverter;
  late ItemRdfMapper itemMapper;
  late RdfMapperRegistry registry;
  late RdfMapperService mapperService;

  setUp(() {
    loggerService = LoggerService();
    typeConverter = RdfTypeConverter(loggerService: loggerService);
    itemMapper = ItemRdfMapper(
      loggerService: loggerService,
      typeConverter: typeConverter,
    );

    registry = RdfMapperRegistry(loggerService: loggerService);
    registry.registerMapper<Item>(itemMapper);

    mapperService = RdfMapperService(
      registry: registry,
      loggerService: loggerService,
      typeConverter: typeConverter,
      serializerFactory: RdfSerializerFactory(loggerService: loggerService),
      parserFactory: RdfParserFactory(loggerService: loggerService),
    );
  });

  group('RdfTypeMapper', () {
    test('Registering and retrieving mappers works', () {
      // Verify that the mapper is registered
      expect(registry.hasMapperFor<Item>(), isTrue);

      // Retrieve the mapper
      final mapper = registry.getMapper<Item>();
      expect(mapper, isNotNull);
      expect(mapper, equals(itemMapper));
    });

    test('Conversion from Item to RDF and back works', () {
      // Create test item
      final originalItem = Item(text: 'Test task', lastModifiedBy: 'test-user');
      originalItem.id = 'test-id-123';
      originalItem.isDeleted = true;
      originalItem.vectorClock = {'user1': 1, 'user2': 2};

      // Generate URI
      final itemUri = itemMapper.generateUri(originalItem);
      expect(
        itemUri,
        equals('${TaskOntologyConstants.taskBaseUri}${originalItem.id}'),
      );

      // Convert to triples
      final triples = itemMapper.toTriples(originalItem, itemUri);
      expect(triples, isNotEmpty);

      // Convert back to Item
      final reconstructedItem = itemMapper.fromTriples(triples, itemUri);

      // Verify properties match
      expect(reconstructedItem.id, equals(originalItem.id));
      expect(reconstructedItem.text, equals(originalItem.text));
      expect(
        reconstructedItem.lastModifiedBy,
        equals(originalItem.lastModifiedBy),
      );
      expect(reconstructedItem.isDeleted, equals(originalItem.isDeleted));
      expect(reconstructedItem.vectorClock, equals(originalItem.vectorClock));
    });
  });

  group('RdfMapperService', () {
    test('Converting item to RDF graph and back works', () {
      // Create test item
      final originalItem = Item(
        text: 'Graph conversion test',
        lastModifiedBy: 'graph-user',
      );
      originalItem.id = 'graph-test-456';
      originalItem.vectorClock = {'user3': 3, 'user4': 4};

      // Convert to graph
      final graph = mapperService.toGraph(originalItem);
      expect(graph.triples, isNotEmpty);

      // Generate URI for lookup
      final itemUri = itemMapper.generateUri(originalItem);

      // Convert back to item
      final reconstructedItem = mapperService.fromGraph<Item>(graph, itemUri);

      // Verify properties match
      expect(reconstructedItem.id, equals(originalItem.id));
      expect(reconstructedItem.text, equals(originalItem.text));
      expect(reconstructedItem.vectorClock, equals(originalItem.vectorClock));
    });

    test('Serializing item to string and back works', () {
      // Create test item
      final originalItem = Item(
        text: 'String serialization test',
        lastModifiedBy: 'string-user',
      );
      originalItem.id = 'string-test-789';
      originalItem.vectorClock = {'user5': 5, 'user6': 6};

      // Convert to string
      final rdfString = mapperService.asString(originalItem);
      expect(rdfString, isNotEmpty);

      // Generate URI for lookup
      final itemUri = itemMapper.generateUri(originalItem);

      // Convert back to item
      final reconstructedItem = mapperService.fromString<Item>(
        rdfString,
        itemUri,
      );

      // Verify properties match
      expect(reconstructedItem.id, equals(originalItem.id));
      expect(reconstructedItem.text, equals(originalItem.text));
      expect(reconstructedItem.vectorClock, equals(originalItem.vectorClock));
    });

    test('Handles special characters in text property', () {
      // Create item with special characters in text
      final originalItem = Item(
        text: 'Test with "quotes", line\nbreaks, and Unicode: ñáéíóú',
        lastModifiedBy: 'special-chars-user',
      );
      originalItem.id = 'special-chars-test';

      // Convert to string and back
      final rdfString = mapperService.asString(originalItem);
      final itemUri = itemMapper.generateUri(originalItem);
      final reconstructedItem = mapperService.fromString<Item>(
        rdfString,
        itemUri,
      );

      // Verify text property is preserved exactly
      expect(reconstructedItem.text, equals(originalItem.text));
    });
  });
}
