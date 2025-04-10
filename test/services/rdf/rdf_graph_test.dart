import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:test/test.dart';

void main() {
  group('RdfGraph', () {
    late RdfGraph graph;

    setUp(() {
      graph = RdfGraph();
    });

    test('should add and retrieve triples', () {
      final triple = Triple(
        'http://example.com/foo',
        'http://example.com/bar',
        'baz',
      );
      graph.addTriple(triple);

      final triples = graph.findTriples(
        subject: 'http://example.com/foo',
        predicate: 'http://example.com/bar',
        object: 'baz',
      );
      expect(triples.length, equals(1));
      expect(triples[0], equals(triple));
    });

    test('should expand prefixed IRIs', () {
      graph.addPrefix('solid', 'http://www.w3.org/ns/solid/terms#');
      graph.addPrefix('space', 'http://www.w3.org/ns/pim/space#');

      expect(
        graph.expandIri('solid:storage'),
        equals('http://www.w3.org/ns/solid/terms#storage'),
      );
      expect(
        graph.expandIri('space:storage'),
        equals('http://www.w3.org/ns/pim/space#storage'),
      );
    });

    test('should handle unknown prefixes', () {
      expect(graph.expandIri('unknown:foo'), equals('unknown:foo'));
    });

    test('should handle full IRIs', () {
      expect(
        graph.expandIri('http://example.com/foo'),
        equals('http://example.com/foo'),
      );
    });

    test('should find triples by pattern', () {
      final triple1 = Triple(
        'http://example.com/foo',
        'http://example.com/bar',
        'baz',
      );
      final triple2 = Triple(
        'http://example.com/foo',
        'http://example.com/qux',
        'quux',
      );
      final triple3 = Triple(
        'http://example.com/bar',
        'http://example.com/bar',
        'baz',
      );

      graph.addTriple(triple1);
      graph.addTriple(triple2);
      graph.addTriple(triple3);

      // Find by subject
      var triples = graph.findTriples(subject: 'http://example.com/foo');
      expect(triples.length, equals(2));
      expect(triples, contains(triple1));
      expect(triples, contains(triple2));

      // Find by predicate
      triples = graph.findTriples(predicate: 'http://example.com/bar');
      expect(triples.length, equals(2));
      expect(triples, contains(triple1));
      expect(triples, contains(triple3));

      // Find by object
      triples = graph.findTriples(object: 'baz');
      expect(triples.length, equals(2));
      expect(triples, contains(triple1));
      expect(triples, contains(triple3));

      // Find by subject and predicate
      triples = graph.findTriples(
        subject: 'http://example.com/foo',
        predicate: 'http://example.com/bar',
      );
      expect(triples.length, equals(1));
      expect(triples[0], equals(triple1));
    });

    test('should handle a complete profile', () {
      graph.addPrefix('solid', 'http://www.w3.org/ns/solid/terms#');
      graph.addPrefix('space', 'http://www.w3.org/ns/pim/space#');

      final profileTriple = Triple(
        'https://example.com/profile#me',
        'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
        'http://www.w3.org/ns/solid/terms#Profile',
      );
      final storageTriple1 = Triple(
        'https://example.com/profile#me',
        'http://www.w3.org/ns/solid/terms#storage',
        'https://example.com/storage/',
      );
      final storageTriple2 = Triple(
        'https://example.com/profile#me',
        'http://www.w3.org/ns/pim/space#storage',
        'https://example.com/storage/',
      );

      graph.addTriple(profileTriple);
      graph.addTriple(storageTriple1);
      graph.addTriple(storageTriple2);

      // Find all storage URLs
      final storageTriples = graph
          .findTriples(subject: 'https://example.com/profile#me')
          .where(
            (triple) =>
                triple.predicate ==
                    'http://www.w3.org/ns/solid/terms#storage' ||
                triple.predicate == 'http://www.w3.org/ns/pim/space#storage',
          );

      expect(storageTriples.length, equals(2));
      expect(
        storageTriples.map((t) => t.object),
        everyElement(equals('https://example.com/storage/')),
      );
    });
  });
}
