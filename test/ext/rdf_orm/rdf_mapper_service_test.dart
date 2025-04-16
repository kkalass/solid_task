import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf/core/graph/triple.dart';
import 'package:solid_task/ext/rdf/core/rdf_parser.dart';
import 'package:solid_task/ext/rdf/core/rdf_serializer.dart';
import 'package:solid_task/ext/rdf_orm/deserialization_context.dart';
import 'package:solid_task/ext/rdf_orm/rdf_mapper_registry.dart';
import 'package:solid_task/ext/rdf_orm/rdf_mapper_service.dart';
import 'package:solid_task/ext/rdf_orm/rdf_subject_mapper.dart';
import 'package:solid_task/ext/rdf_orm/serialization_context.dart';

class TestItem {
  final String name;
  final int age;

  TestItem({required this.name, required this.age});
}

final class TestItemRdfMapper implements RdfSubjectMapper<TestItem> {
  @override
  final IriTerm typeIri = IriTerm(
    "http://kalass.de/dart/rdf/test-ontology#TestItem",
  );

  @override
  TestItem fromIriTerm(IriTerm iri, DeserializationContext context) {
    return TestItem(
      name: context.getRequiredPropertyValue(
        iri,
        IriTerm("http://kalass.de/dart/rdf/test-ontology#name"),
      ),
      age: context.getRequiredPropertyValue(
        iri,
        IriTerm("http://kalass.de/dart/rdf/test-ontology#age"),
      ),
    );
  }

  @override
  (RdfSubject, List<Triple>) toRdfSubject(
    TestItem instance,
    SerializationContext context, {
    RdfSubject? parentSubject,
  }) {
    final itemIri = IriTerm(
      context.storageRoot + Uri.encodeComponent(instance.name),
    );

    return (
      itemIri,
      [
        // Add basic properties
        context.literal(
          itemIri,
          IriTerm("http://kalass.de/dart/rdf/test-ontology#name"),
          instance.name,
        ),

        context.literal(
          itemIri,
          IriTerm("http://kalass.de/dart/rdf/test-ontology#age"),
          instance.age,
        ),
      ],
    );
  }
}

const storageRoot = "https://example.com/pod/";

void main() {
  late RdfMapperRegistry registry;
  late RdfMapperService mapperService;

  setUp(() {
    registry = RdfMapperRegistry();
    registry.registerSubjectMapper<TestItem>(TestItemRdfMapper());

    mapperService = RdfMapperService(registry: registry);
  });

  group('RdfMapperRegistry', () {
    test('Registering and retrieving mappers works', () {
      // Verify that the mapper is registered
      expect(registry.hasSubjectDeserializerFor<TestItem>(), isTrue);
      expect(registry.hasSubjectSerializerFor<TestItem>(), isTrue);

      // Retrieve the mapper
      final deserializer = registry.getSubjectDeserializer<TestItem>();
      expect(deserializer, isNotNull);
      expect(deserializer, isA<TestItemRdfMapper>());
      final serializer = registry.getSubjectSerializer<TestItem>();
      expect(serializer, isNotNull);
      expect(serializer, equals(isA<TestItemRdfMapper>()));
    });
  });

  group('RdfMapperService', () {
    test('Converting item to RDF graph and back works', () {
      // Create test item
      final originalItem = TestItem(name: 'Graph conversion test', age: 42);

      // Convert to graph
      final graph = mapperService.toGraph<TestItem>(storageRoot, originalItem);
      expect(graph.triples, isNotEmpty);

      // Convert back to item
      final reconstructedItem = mapperService.fromGraph<TestItem>(
        storageRoot,
        graph,
        graph.triples[0].subject as IriTerm,
      );

      // Verify properties match
      expect(reconstructedItem.name, equals(originalItem.name));
      expect(reconstructedItem.age, equals(originalItem.age));
    });

    test('Converting item to turtle', () {
      final serializer = RdfSerializerFactory().createSerializer();
      // Create test item
      final originalItem = TestItem(name: 'Graph Conversion Test', age: 42);

      // Convert to graph
      final graph = mapperService.toGraph<TestItem>(storageRoot, originalItem);
      expect(graph.triples, isNotEmpty);
      final turtle = serializer.write(graph);

      // Verify generated turtle
      expect(
        turtle,
        equals(
          """
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

<https://example.com/pod/Graph%20Conversion%20Test> a <http://kalass.de/dart/rdf/test-ontology#TestItem>;
    <http://kalass.de/dart/rdf/test-ontology#name> "Graph Conversion Test";
    <http://kalass.de/dart/rdf/test-ontology#age> "42"^^xsd:integer .
""".trim(),
        ),
      );
    });

    test('Converting item to turtle with prefixes', () {
      final serializer = RdfSerializerFactory().createSerializer();
      // Create test item
      final originalItem = TestItem(name: 'Graph Conversion Test', age: 42);

      // Convert to graph
      final graph = mapperService.toGraph<TestItem>(storageRoot, originalItem);
      expect(graph.triples, isNotEmpty);
      final turtle = serializer.write(
        graph,
        customPrefixes: {"test": "http://kalass.de/dart/rdf/test-ontology#"},
      );

      // Verify generated turtle
      expect(
        turtle,
        equals(
          """
@prefix test: <http://kalass.de/dart/rdf/test-ontology#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

<https://example.com/pod/Graph%20Conversion%20Test> a test:TestItem;
    test:name "Graph Conversion Test";
    test:age "42"^^xsd:integer .
""".trim(),
        ),
      );
    });

    test('Converting item from turtle ', () {
      final parser = RdfParserFactory().createParser();
      // Create test item
      final turtle = """
@prefix test: <http://kalass.de/dart/rdf/test-ontology#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

<https://example.com/pod/Graph%20Conversion%20Test> a test:TestItem;
    test:name "Graph Conversion Test";
    test:age "42"^^xsd:integer .
""";

      // Convert to graph
      final graph = parser.parse(turtle);
      final allSubjects = mapperService.fromGraphAllSubjects(
        storageRoot,
        graph,
      );

      // Verify generated turtle
      expect(allSubjects.length, equals(1));
      expect(allSubjects[0], isA<TestItem>());
      var item = allSubjects[0] as TestItem;
      expect(item.name, "Graph Conversion Test");
      expect(item.age, 42);
    });
  });
}
