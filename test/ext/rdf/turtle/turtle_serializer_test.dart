import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/ext/rdf/core/constants/xsd_constants.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_graph.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf/core/graph/triple.dart';
import 'package:solid_task/ext/rdf/turtle/turtle_serializer.dart';

void main() {
  late TurtleSerializer serializer;

  setUp(() {
    serializer = TurtleSerializer();
  });

  group('TurtleSerializer', () {
    test('should serialize empty graph', () {
      // Arrange
      final graph = RdfGraph();

      // Act
      final result = serializer.write(graph);

      // Assert
      expect(result, isEmpty);
    });

    test('should serialize graph with prefixes', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm("http://example.org/test"),
            IriTerm("http://my-ontology.org/test#deleted"),
            LiteralTerm("true", datatype: XsdConstants.booleanIri),
          ),
        ],
      );
      final prefixes = {'ex': 'http://example.org/'};

      // Act
      final result = serializer.write(graph, customPrefixes: prefixes);

      // Assert
      expect(
        result,
        contains('@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .'),
      );
      expect(result, contains('@prefix ex: <http://example.org/> .'));
    });

    test('should serialize a simple triple', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/alice'),
            IriTerm('http://example.org/knows'),
            IriTerm('http://example.org/bob'),
          ),
        ],
      );

      // Act
      final result = serializer.write(graph);

      // Assert
      expect(
        result,
        contains(
          '<http://example.org/alice> <http://example.org/knows> <http://example.org/bob> .',
        ),
      );
    });

    test('should use rdf:type abbreviation', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/alice'),
            IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
            IriTerm('http://example.org/Person'),
          ),
        ],
      );

      // Act
      final result = serializer.write(graph);

      // Assert
      expect(
        result,
        contains('<http://example.org/alice> a <http://example.org/Person> .'),
      );
      expect(
        result,
        isNot(contains('<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>')),
      );
    });

    test('should group triples by subject', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/alice'),
            IriTerm('http://example.org/name'),
            LiteralTerm.string('Alice'),
          ),
          Triple(
            IriTerm('http://example.org/alice'),
            IriTerm('http://example.org/age'),
            LiteralTerm(
              "30",
              datatype: IriTerm('http://www.w3.org/2001/XMLSchema#integer'),
            ),
          ),
          Triple(
            IriTerm('http://example.org/bob'),
            IriTerm('http://example.org/name'),
            LiteralTerm.string('Bob'),
          ),
        ],
      );

      // Act
      final result = serializer.write(graph);

      // Assert
      expect(
        result,
        contains(
          '<http://example.org/alice> <http://example.org/name> "Alice"',
        ),
      );
      expect(
        result,
        contains(
          '<http://example.org/alice> <http://example.org/name> "Alice";\n    <http://example.org/age> "30"^^xsd:integer',
        ),
      );
      expect(
        result,
        contains('<http://example.org/bob> <http://example.org/name> "Bob" .'),
      );

      // Check subject grouping
      expect(
        result.split('\n').length,
        5,
      ); // Two subjects = two groups, but one subject has two predicates, plus a prefix line for xsd and a blank one after the prefix
    });

    test('should group multiple objects for the same predicate', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/alice'),
            IriTerm('http://example.org/likes'),
            IriTerm('http://example.org/chocolate'),
          ),
          Triple(
            IriTerm('http://example.org/alice'),
            IriTerm('http://example.org/likes'),
            IriTerm('http://example.org/pizza'),
          ),
        ],
      );

      // Act
      final result = serializer.write(graph);

      // Assert
      expect(
        result,
        contains(
          '<http://example.org/alice> <http://example.org/likes> <http://example.org/chocolate>, <http://example.org/pizza> .',
        ),
      );
    });

    test('should handle blank nodes', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/statement'),
            IriTerm('http://example.org/source'),
            BlankNodeTerm('b1'),
          ),
        ],
      );

      // Act
      final result = serializer.write(graph);

      // Assert
      expect(
        result,
        contains(
          '<http://example.org/statement> <http://example.org/source> _:b1 .',
        ),
      );
    });

    test('should handle literals with language tags', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/book'),
            IriTerm('http://example.org/title'),
            LiteralTerm.withLanguage('Le Petit Prince', 'fr'),
          ),
        ],
      );

      // Act
      final result = serializer.write(graph);

      // Assert
      expect(
        result,
        contains(
          '<http://example.org/book> <http://example.org/title> "Le Petit Prince"@fr .',
        ),
      );
    });

    test('should handle literals with quotes and backslashes', () {
      // Arrange
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('http://example.org/book'),
            IriTerm('http://example.org/title'),
            LiteralTerm.string(
              'Le "Petit" \\ Prince\n hopes for a better world\r',
            ),
          ),
        ],
      );

      // Act
      final result = serializer.write(graph);

      // Assert
      expect(
        result,
        contains(
          '<http://example.org/book> <http://example.org/title> "Le \\"Petit\\" \\\\ Prince\\n hopes for a better world\\r" .',
        ),
      );
    });

    test(
      'should handle complex graphs with multiple subjects and predicates and make use of prefixes',
      () {
        // Arrange
        final graph = RdfGraph(
          triples: [
            // Person 1
            Triple(
              IriTerm('http://example.org/alice'),
              IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
              IriTerm('http://xmlns.com/foaf/0.1/Person'),
            ),
            Triple(
              IriTerm('http://example.org/alice'),
              IriTerm('http://xmlns.com/foaf/0.1/name'),
              LiteralTerm.string('Alice'),
            ),
            Triple(
              IriTerm('http://example.org/alice'),
              IriTerm('http://xmlns.com/foaf/0.1/knows'),
              IriTerm('http://example.org/bob'),
            ),
            // Person 2
            Triple(
              IriTerm('http://example.org/bob'),
              IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
              IriTerm('http://xmlns.com/foaf/0.1/Person'),
            ),
            Triple(
              IriTerm('http://example.org/bob'),
              IriTerm('http://xmlns.com/foaf/0.1/name'),
              LiteralTerm.string('Bob'),
            ),
          ],
        );

        final prefixes = {'ex': 'http://example.org/'};

        // Act
        final result = serializer.write(graph, customPrefixes: prefixes);

        // Assert
        expect(result, contains('@prefix ex: <http://example.org/> .'));
        expect(
          result,
          contains('@prefix foaf: <http://xmlns.com/foaf/0.1/> .'),
        );
        expect(result, contains('ex:alice a foaf:Person'));
        expect(result, contains('foaf:name "Alice"'));
        expect(result, contains('    foaf:knows ex:bob'));
        expect(result, contains('ex:bob a foaf:Person'));
        expect(result, contains('    foaf:name "Bob"'));
      },
    );
  });
}
