import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_graph.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf/core/graph/triple.dart';
import 'package:solid_task/ext/rdf/core/rdf_serializer.dart';
import 'package:solid_task/ext/rdf/turtle/turtle_serializer.dart';

void main() {
  late RdfSerializerFactory factory;
  setUp(() {
    factory = RdfSerializerFactory();
  });

  group('RdfSerializerFactory', () {
    test('should create TurtleSerializer for text/turtle content type', () {
      // Arrange & Act
      final serializer = factory.createSerializer(contentType: 'text/turtle');

      // Assert
      expect(serializer, isA<TurtleSerializer>());
    });

    test('should create TurtleSerializer when content type is null', () {
      // Arrange & Act
      final serializer = factory.createSerializer();

      // Assert
      expect(serializer, isA<TurtleSerializer>());
    });

    test('should create TurtleSerializer for unrecognized content type', () {
      // Arrange & Act
      final serializer = factory.createSerializer(
        contentType: 'application/unknown',
      );

      // Assert
      expect(serializer, isA<TurtleSerializer>());
    });

    test('should throw UnimplementedError for JSON-LD', () {
      // Arrange & Act & Assert
      expect(
        () => factory.createSerializer(contentType: 'application/ld+json'),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('should delegate to appropriate serializer based on content type', () {
      // Arrange
      final prefixes = {'ex': 'http://example.org/'};
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/predicate'),
            LiteralTerm.string("object"),
          ),
        ],
      );

      final defaultSerializer = RdfSerializerFactory().createSerializer();

      // Act
      final result = defaultSerializer.write(graph, customPrefixes: prefixes);

      // Assert
      expect(result, contains('@prefix ex:'));
      expect(result, contains('ex:subject'));
      expect(result, contains('ex:predicate'));
      expect(result, contains('"object"'));
    });
  });
}
