import 'package:flutter_test/flutter_test.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/solid_integration/item_rdf_mapper.dart';

const storageRoot = "https://example.com/pod/";
void main() {
  late LoggerService loggerService;
  late ItemRdfMapper itemMapper;
  late RdfMapper rdfMapper;

  setUp(() {
    loggerService = LoggerService();
    itemMapper = ItemRdfMapper(
      loggerService: loggerService,
      storageRootProvider: () => storageRoot,
    );

    rdfMapper = RdfMapper.withDefaultRegistry()..registerMapper(itemMapper);
  });

  group('RdfMapperRegistry', () {
    test('Registering and retrieving mappers works', () {
      // Verify that the mapper is registered
      expect(rdfMapper.registry.hasIriNodeDeserializerFor<Item>(), isTrue);
      expect(rdfMapper.registry.hasNodeSerializerFor<Item>(), isTrue);

      // Retrieve the mapper
      final deserializer = rdfMapper.registry.getIriNodeDeserializer<Item>();
      expect(deserializer, isNotNull);
      expect(deserializer, equals(itemMapper));
      final serializer = rdfMapper.registry.getNodeSerializer<Item>();
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
      final graph = rdfMapper.graph.serialize(originalItem);
      expect(graph.triples, isNotEmpty);

      // Convert back to item
      final reconstructedItem = rdfMapper.graph.deserializeBySubject<Item>(
        graph,
        IriTerm("${storageRoot}solidtask/task/graph-test-456.ttl"),
      );
      final reconstructedItem2 = rdfMapper.graph.deserialize<Item>(graph);

      // Verify properties match
      expect(reconstructedItem.id, equals(originalItem.id));
      expect(reconstructedItem2.id, equals(originalItem.id));
      expect(reconstructedItem.text, equals(originalItem.text));
      expect(reconstructedItem2.text, equals(originalItem.text));
      expect(reconstructedItem.vectorClock, equals(originalItem.vectorClock));
      expect(reconstructedItem2.vectorClock, equals(originalItem.vectorClock));
    });
  });
}
