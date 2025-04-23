import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_graph.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf/core/graph/triple.dart';
import 'package:solid_task/ext/rdf/core/rdf_serializer.dart';
import 'package:solid_task/ext/rdf/turtle/turtle_serializer.dart';

void main() {
  group('RdfSerializerFactory', () {
    late RdfSerializerFactory factory;

    setUp(() {
      factory = RdfSerializerFactory();
    });

    test(
      'should create Turtle serializer by default when no content type is specified',
      () {
        final serializer = factory.createSerializer();

        // Create a simple graph
        final graph = RdfGraph(
          triples: [
            Triple(
              IriTerm('http://example.org/subject'),
              IriTerm('http://example.org/predicate'),
              LiteralTerm.string('object'),
            ),
          ],
        );

        // Serialize it and verify it looks like Turtle
        final output = serializer.write(graph);

        expect(output, isNotEmpty);
        // Simple test for Turtle syntax: should contain the IRI enclosed in angle brackets
        expect(output, contains('<http://example.org/subject>'));
        expect(output, contains('<http://example.org/predicate>'));
        expect(output, contains('"object"'));
      },
    );

    test('should create Turtle serializer for text/turtle content type', () {
      final serializer = factory.createSerializer(contentType: 'text/turtle');

      // Create a simple graph
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/predicate'),
            LiteralTerm.string('object'),
          ),
        ],
      );

      // Serialize it and verify it looks like Turtle
      final output = serializer.write(graph);

      expect(output, contains('<http://example.org/subject>'));
      expect(output, contains('<http://example.org/predicate>'));
      expect(output, contains('"object"'));
    });

    test('should handle content type with parameters', () {
      final serializer = factory.createSerializer(
        contentType: 'text/turtle; charset=UTF-8',
      );

      // Create a simple graph
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/predicate'),
            LiteralTerm.string('object'),
          ),
        ],
      );

      // Verify it's recognized as Turtle
      final output = serializer.write(graph);
      expect(output, contains('<http://example.org/subject>'));
    });

    test('should fall back to Turtle for unrecognized content type', () {
      final serializer = factory.createSerializer(
        contentType: 'application/unknown',
      );

      // Create a simple graph
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/predicate'),
            LiteralTerm.string('object'),
          ),
        ],
      );

      // Verify it falls back to Turtle
      final output = serializer.write(graph);
      expect(output, contains('<http://example.org/subject>'));
    });

    test('should throw UnimplementedError for JSON-LD content type', () {
      // JSON-LD serializer is not implemented yet
      expect(
        () => factory.createSerializer(contentType: 'application/ld+json'),
        throwsUnimplementedError,
      );
    });

    test('should handle custom prefixes', () {
      final serializer = factory.createSerializer(contentType: 'text/turtle');

      // Create a simple graph with IRIs that could use prefixes
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/predicate'),
            LiteralTerm.string('object'),
          ),
        ],
      );

      // Add custom prefixes
      final customPrefixes = {'ex': 'http://example.org/'};

      // Serialize with custom prefixes
      final output = serializer.write(graph, customPrefixes: customPrefixes);

      // Verify prefixes are used
      expect(output, contains('@prefix ex: <http://example.org/> .'));
      expect(output, contains('ex:subject ex:predicate "object" .'));
    });

    test('should handle empty graph', () {
      final serializer = factory.createSerializer();
      final emptyGraph = RdfGraph();

      final output = serializer.write(emptyGraph);
      expect(output, isEmpty);
    });

    test('should preserve special characters in literals', () {
      final serializer = factory.createSerializer();

      // Create a graph with a literal containing special characters
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/subject'),
            IriTerm('http://example.org/predicate'),
            LiteralTerm.string(
              'Special "characters" with \\ backslashes and \n newlines',
            ),
          ),
        ],
      );

      final output = serializer.write(graph);

      // Special characters should be escaped properly
      expect(
        output,
        contains(
          '"Special \\"characters\\" with \\\\ backslashes and \\n newlines"',
        ),
      );
    });
  });
}
