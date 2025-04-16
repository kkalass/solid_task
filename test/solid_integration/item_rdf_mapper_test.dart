import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf_orm/rdf_mapper_registry.dart';
import 'package:solid_task/ext/rdf_orm/rdf_mapper_service.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/solid_integration/item_rdf_mapper.dart';

const storageRoot = "https://example.com/pod/";
void main() {
  late LoggerService loggerService;
  late ItemRdfMapper itemMapper;
  late RdfMapperRegistry registry;
  late RdfMapperService mapperService;

  setUp(() {
    loggerService = LoggerService();
    itemMapper = ItemRdfMapper(loggerService: loggerService);

    registry = RdfMapperRegistry();
    registry.registerSubjectMapper<Item>(itemMapper);

    mapperService = RdfMapperService(registry: registry);
  });

  group('RdfMapperRegistry', () {
    test('Registering and retrieving mappers works', () {
      // Verify that the mapper is registered
      expect(registry.hasSubjectDeserializerFor<Item>(), isTrue);
      expect(registry.hasSubjectSerializerFor<Item>(), isTrue);

      // Retrieve the mapper
      final deserializer = registry.getSubjectDeserializer<Item>();
      expect(deserializer, isNotNull);
      expect(deserializer, equals(itemMapper));
      final serializer = registry.getSubjectSerializer<Item>();
      expect(serializer, isNotNull);
      expect(serializer, equals(itemMapper));
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
      final graph = mapperService.toGraph(storageRoot, originalItem);
      expect(graph.triples, isNotEmpty);

      // Convert back to item
      final reconstructedItem = mapperService.fromGraph<Item>(
        storageRoot,
        graph,
        IriTerm("${storageRoot}solidtask/task/graph-test-456.ttl"),
      );

      // Verify properties match
      expect(reconstructedItem.id, equals(originalItem.id));
      expect(reconstructedItem.text, equals(originalItem.text));
      expect(reconstructedItem.vectorClock, equals(originalItem.vectorClock));
    });
  });
}
