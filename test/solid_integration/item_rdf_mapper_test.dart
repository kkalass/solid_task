import 'package:flutter_test/flutter_test.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:solid_task/init_rdf_mapper.g.dart';
import 'package:solid_task/models/item.dart';

const storageRoot = "https://example.com/pod/";
void main() {
  late RdfMapper rdfMapper;

  setUp(() {
    rdfMapper = initRdfMapper(storageRootProvider: () => 'http://my.test.pod');
  });

  group('RdfMapperRegistry', () {
    test('Registering and retrieving mappers works', () {
      // Verify that the mapper is registered
      expect(
        rdfMapper.registry.hasGlobalResourceDeserializerFor<Item>(),
        isTrue,
      );
      expect(rdfMapper.registry.hasResourceSerializerFor<Item>(), isTrue);

      // Retrieve the mapper
      final deserializer =
          rdfMapper.registry.getGlobalResourceDeserializer<Item>();
      expect(deserializer, isNotNull);
      final serializer = rdfMapper.registry.getResourceSerializer<Item>();
      expect(serializer, isNotNull);
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
      final graph = rdfMapper.graph.encodeObject(originalItem);
      expect(graph.triples, isNotEmpty);

      // Convert back to item
      final reconstructedItem = rdfMapper.graph.decodeObject<Item>(
        graph,
        subject: IriTerm("${storageRoot}solidtask/task/graph-test-456.ttl"),
      );
      final reconstructedItem2 = rdfMapper.graph.decodeObject<Item>(graph);

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
