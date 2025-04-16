import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_graph.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf/core/graph/triple.dart';
import 'package:solid_task/ext/rdf/turtle/turtle_serializer.dart';

void main() {
  group('RdfGraph', () {
    test('langTerm', () {
      final langTerm = LiteralTerm.withLanguage('Hello', 'en');
      expect(TurtleSerializer().writeTerm(langTerm), equals('"Hello"@en'));
    });

    test('illegal langTerm', () {
      expect(
        () => LiteralTerm(
          'Hello',
          datatype: IriTerm("http://example.com/foo"),
          language: 'en',
        ),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            'Language-tagged literals must use rdf:langString datatype, and rdf:langString must have a language tag',
          ),
        ),
      );
    });

    test('legal langTerm alternative construction', () {
      var baseIri = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
      var type = "langString";
      final langTerm = LiteralTerm(
        'Hello',
        datatype: IriTerm("$baseIri$type"),
        language: 'en',
      );
      expect(TurtleSerializer().writeTerm(langTerm), equals('"Hello"@en'));
    });

    // Tests for the new immutable RdfGraph implementation
    group('Immutable RdfGraph', () {
      test('should create empty graph', () {
        final graph = RdfGraph();
        expect(graph.isEmpty, isTrue);
        expect(graph.size, equals(0));
      });

      test('should create graph with initial triples', () {
        final triple = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final graph = RdfGraph(triples: [triple]);
        expect(graph.isEmpty, isFalse);
        expect(graph.size, equals(1));
        expect(graph.triples, contains(triple));
      });

      test('should add triples immutably with withTriple', () {
        final triple1 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/qux'),
          LiteralTerm.string('quux'),
        );

        final graph1 = RdfGraph();
        final graph2 = graph1.withTriple(triple1);
        final graph3 = graph2.withTriple(triple2);

        // Original graph should remain empty
        expect(graph1.isEmpty, isTrue);

        // Second graph should have only triple1
        expect(graph2.size, equals(1));
        expect(graph2.triples, contains(triple1));
        expect(graph2.triples, isNot(contains(triple2)));

        // Third graph should have both triples
        expect(graph3.size, equals(2));
        expect(graph3.triples, contains(triple1));
        expect(graph3.triples, contains(triple2));
      });

      test('should add multiple triples immutably with withTriples', () {
        final triple1 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/qux'),
          LiteralTerm.string('quux'),
        );

        final graph1 = RdfGraph();
        final graph2 = graph1.withTriples([triple1, triple2]);

        // Original graph should remain empty
        expect(graph1.isEmpty, isTrue);

        // New graph should have both triples
        expect(graph2.size, equals(2));
        expect(graph2.triples, contains(triple1));
        expect(graph2.triples, contains(triple2));
      });

      test('should find triples by pattern', () {
        final triple1 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/qux'),
          LiteralTerm.string('quux'),
        );

        final triple3 = Triple(
          IriTerm('http://example.com/bar'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final graph = RdfGraph()
            .withTriple(triple1)
            .withTriple(triple2)
            .withTriple(triple3);

        // Find by subject
        var triples = graph.findTriples(
          subject: IriTerm('http://example.com/foo'),
        );
        expect(triples.length, equals(2));
        expect(triples, contains(triple1));
        expect(triples, contains(triple2));

        // Find by predicate
        triples = graph.findTriples(
          predicate: IriTerm('http://example.com/bar'),
        );
        expect(triples.length, equals(2));
        expect(triples, contains(triple1));
        expect(triples, contains(triple3));

        // Find by object
        triples = graph.findTriples(object: LiteralTerm.string('baz'));
        expect(triples.length, equals(2));
        expect(triples, contains(triple1));
        expect(triples, contains(triple3));

        // Find by subject and predicate
        triples = graph.findTriples(
          subject: IriTerm('http://example.com/foo'),
          predicate: IriTerm('http://example.com/bar'),
        );
        expect(triples.length, equals(1));
        expect(triples[0], equals(triple1));
      });

      test('should get objects for subject and predicate', () {
        final subject = IriTerm('http://example.com/foo');
        final predicate = IriTerm('http://example.com/bar');
        final object1 = LiteralTerm.string('baz');
        final object2 = LiteralTerm.string('qux');

        final graph = RdfGraph()
            .withTriple(Triple(subject, predicate, object1))
            .withTriple(Triple(subject, predicate, object2));

        final objects = graph.getObjects(subject, predicate);
        expect(objects.length, equals(2));
        expect(objects, contains(object1));
        expect(objects, contains(object2));
      });

      test('should get subjects for predicate and object', () {
        final subject1 = IriTerm('http://example.com/foo');
        final subject2 = IriTerm('http://example.com/bar');
        final predicate = IriTerm('http://example.com/baz');
        final object = LiteralTerm.string('qux');

        final graph = RdfGraph()
            .withTriple(Triple(subject1, predicate, object))
            .withTriple(Triple(subject2, predicate, object));

        final subjects = graph.getSubjects(predicate, object);
        expect(subjects.length, equals(2));
        expect(subjects, contains(subject1));
        expect(subjects, contains(subject2));
      });

      test('should filter triples with withoutMatching', () {
        final triple1 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/qux'),
          LiteralTerm.string('quux'),
        );

        final triple3 = Triple(
          IriTerm('http://example.com/bar'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final graph = RdfGraph()
            .withTriple(triple1)
            .withTriple(triple2)
            .withTriple(triple3);

        // Filter by subject
        final filteredBySubject = graph.withoutMatching(
          subject: IriTerm('http://example.com/foo'),
        );
        expect(filteredBySubject.size, equals(1));
        expect(filteredBySubject.triples, contains(triple3));

        // Filter by predicate
        final filteredByPredicate = graph.withoutMatching(
          predicate: IriTerm('http://example.com/bar'),
        );
        expect(filteredByPredicate.size, equals(1));
        expect(filteredByPredicate.triples, contains(triple2));

        // Filter by object
        final filteredByObject = graph.withoutMatching(
          object: LiteralTerm.string('baz'),
        );
        expect(filteredByObject.size, equals(1));
        expect(filteredByObject.triples, contains(triple2));
      });

      test('should merge graphs immutably', () {
        final triple1 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/qux'),
          LiteralTerm.string('quux'),
        );

        final graph1 = RdfGraph().withTriple(triple1);
        final graph2 = RdfGraph().withTriple(triple2);

        final mergedGraph = graph1.merge(graph2);

        // Original graphs should remain unchanged
        expect(graph1.size, equals(1));
        expect(graph1.triples, contains(triple1));
        expect(graph1.triples, isNot(contains(triple2)));

        expect(graph2.size, equals(1));
        expect(graph2.triples, contains(triple2));
        expect(graph2.triples, isNot(contains(triple1)));

        // Merged graph should have both triples
        expect(mergedGraph.size, equals(2));
        expect(mergedGraph.triples, contains(triple1));
        expect(mergedGraph.triples, contains(triple2));
      });

      test('should implement equality correctly', () {
        final triple1 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/bar'),
          LiteralTerm.string('baz'),
        );

        final triple2 = Triple(
          IriTerm('http://example.com/foo'),
          IriTerm('http://example.com/qux'),
          LiteralTerm.string('quux'),
        );

        final graph1 = RdfGraph().withTriple(triple1).withTriple(triple2);

        final graph2 = RdfGraph().withTriple(triple2).withTriple(triple1);

        // Same triples in different order should be equal
        expect(graph1 == graph2, isTrue);
        expect(graph1.hashCode, equals(graph2.hashCode));

        // Different graphs should not be equal
        final graph3 = RdfGraph().withTriple(triple1);
        expect(graph1 == graph3, isFalse);
      });

      group('groupByStorageIri', () {
        test('groups IRI-based triples by their storage IRI', () {
          // Create sample IRI terms for subjects
          final subject1 = IriTerm('http://example.org/resource#fragment');
          final subject2 = IriTerm('http://example.org/resource#another');
          final subject3 = IriTerm('http://example.org/other#fragment');
          final subject4 = IriTerm('urn:uuid:123456');
          final subject5 = IriTerm('mailto:user@example.org');

          // Create a predicate
          final predicate = IriTerm('http://example.org/property');

          // Create objects
          final object1 = LiteralTerm.string('Value 1');
          final object2 = LiteralTerm.string('Value 2');

          // Create triples
          final triple1 = Triple(subject1, predicate, object1);
          final triple2 = Triple(subject2, predicate, object2);
          final triple3 = Triple(subject3, predicate, object1);
          final triple4 = Triple(subject4, predicate, object2);
          final triple5 = Triple(subject5, predicate, object1);

          // Create a graph with these triples
          final graph = RdfGraph(
            triples: [triple1, triple2, triple3, triple4, triple5],
          );

          // Group by storage IRI
          final grouped = graph.groupByStorageIri();

          // Expected storage IRIs as keys
          final storageIri1 = IriTerm('http://example.org/resource');
          final storageIri2 = IriTerm('http://example.org/other');
          final storageIri3 = IriTerm('urn:uuid:123456');
          final storageIri4 = IriTerm('mailto:user@example.org');

          // Verify the results
          expect(grouped.keys.length, equals(4));

          // HTTP IRIs with fragments should be grouped by their base
          expect(grouped[storageIri1]!.length, equals(2));
          expect(grouped[storageIri1]!.contains(triple1), isTrue);
          expect(grouped[storageIri1]!.contains(triple2), isTrue);

          // Another HTTP IRI with different base
          expect(grouped[storageIri2]!.length, equals(1));
          expect(grouped[storageIri2]!.contains(triple3), isTrue);

          // Non-HTTP IRIs should be grouped by their entire IRI
          expect(grouped[storageIri3]!.length, equals(1));
          expect(grouped[storageIri3]!.contains(triple4), isTrue);

          expect(grouped[storageIri4]!.length, equals(1));
          expect(grouped[storageIri4]!.contains(triple5), isTrue);
        });

        test('groups blank node triples with their referencing subjects', () {
          // Create IRI subjects
          final iriSubject1 = IriTerm('http://example.org/resource1');
          final iriSubject2 = IriTerm('http://example.org/resource2');

          // Create blank nodes
          final blankNode1 = BlankNodeTerm('blank1');
          final blankNode2 = BlankNodeTerm('blank2');
          final blankNode3 = BlankNodeTerm('blank3');

          // Create predicate and objects
          final predicate = IriTerm('http://example.org/property');
          final object1 = LiteralTerm.string('Value 1');
          final object2 = LiteralTerm.string('Value 2');

          // Create triples:
          // 1. IRI -> BlankNode reference
          final triple1 = Triple(iriSubject1, predicate, blankNode1);
          // 2. BlankNode -> Literal
          final triple2 = Triple(blankNode1, predicate, object1);
          // 3. BlankNode -> BlankNode reference
          final triple3 = Triple(blankNode1, predicate, blankNode2);
          // 4. Second-level BlankNode -> Literal
          final triple4 = Triple(blankNode2, predicate, object2);
          // 5. Another IRI referencing a different BlankNode
          final triple5 = Triple(iriSubject2, predicate, blankNode3);
          // 6. That BlankNode's triple
          final triple6 = Triple(blankNode3, predicate, object2);

          // Create a graph with these triples
          final graph = RdfGraph(
            triples: [triple1, triple2, triple3, triple4, triple5, triple6],
          );

          // Group by storage IRI
          final grouped = graph.groupByStorageIri();

          // Expected storage IRIs as keys
          final storageIri1 = IriTerm('http://example.org/resource1');
          final storageIri2 = IriTerm('http://example.org/resource2');

          // Verify the results
          expect(grouped.keys.length, equals(2));

          // The first IRI subject and all blank nodes it references (directly or indirectly)
          // should be grouped together
          expect(grouped[storageIri1]!.length, equals(4));
          expect(grouped[storageIri1]!.contains(triple1), isTrue);
          expect(grouped[storageIri1]!.contains(triple2), isTrue);
          expect(grouped[storageIri1]!.contains(triple3), isTrue);
          expect(grouped[storageIri1]!.contains(triple4), isTrue);

          // The second IRI subject and its referenced blank node should be in another group
          expect(grouped[storageIri2]!.length, equals(2));
          expect(grouped[storageIri2]!.contains(triple5), isTrue);
          expect(grouped[storageIri2]!.contains(triple6), isTrue);
        });

        test('handles complex blank node chains correctly', () {
          // Create IRI subject
          final iriSubject = IriTerm('http://example.org/resource');

          // Create blank nodes forming a chain
          final blankNode1 = BlankNodeTerm('blank1');
          final blankNode2 = BlankNodeTerm('blank2');
          final blankNode3 = BlankNodeTerm('blank3');

          // Create predicate and objects
          final predicate = IriTerm('http://example.org/property');
          final object = LiteralTerm.string('Value');

          // Create triples forming a chain: IRI -> blank1 -> blank2 -> blank3 -> Literal
          final triple1 = Triple(iriSubject, predicate, blankNode1);
          final triple2 = Triple(blankNode1, predicate, blankNode2);
          final triple3 = Triple(blankNode2, predicate, blankNode3);
          final triple4 = Triple(blankNode3, predicate, object);

          // Create a graph with these triples
          final graph = RdfGraph(triples: [triple1, triple2, triple3, triple4]);

          // Group by storage IRI
          final grouped = graph.groupByStorageIri();

          // Expected storage IRI
          final storageIri = IriTerm('http://example.org/resource');

          // Verify the results - all triples should be in one group
          expect(grouped.keys.length, equals(1));
          expect(grouped[storageIri]!.length, equals(4));
          expect(grouped[storageIri]!.contains(triple1), isTrue);
          expect(grouped[storageIri]!.contains(triple2), isTrue);
          expect(grouped[storageIri]!.contains(triple3), isTrue);
          expect(grouped[storageIri]!.contains(triple4), isTrue);
        });

        test('handles orphaned blank nodes', () {
          // Create IRI subject
          final iriSubject = IriTerm('http://example.org/resource');

          // Create blank nodes - one referenced, one orphaned
          final blankNode1 = BlankNodeTerm('blank1');
          final blankNode2 = BlankNodeTerm('blank2');

          // Create predicate and objects
          final predicate = IriTerm('http://example.org/property');
          final object = LiteralTerm.string('Value');

          // Create triples:
          // 1. IRI -> referenced blank node
          final triple1 = Triple(iriSubject, predicate, blankNode1);
          // 2. Referenced blank node -> literal
          final triple2 = Triple(blankNode1, predicate, object);
          // 3. Orphaned blank node -> literal (no IRI references this blank node)
          final triple3 = Triple(blankNode2, predicate, object);

          // Create a graph with these triples
          final graph = RdfGraph(triples: [triple1, triple2, triple3]);

          // Group by storage IRI
          final grouped = graph.groupByStorageIri();

          // Expected storage IRIs
          final storageIri = IriTerm('http://example.org/resource');
          final orphanedIri = IriTerm('tag:orphaned');

          // Verify the results
          expect(grouped.keys.length, equals(2));

          // Referenced blank node should be with the IRI
          expect(grouped[storageIri]!.length, equals(2));
          expect(grouped[storageIri]!.contains(triple1), isTrue);
          expect(grouped[storageIri]!.contains(triple2), isTrue);

          // Orphaned blank node should be in the special orphaned group
          expect(grouped[orphanedIri]!.length, equals(1));
          expect(grouped[orphanedIri]!.contains(triple3), isTrue);
        });

        test('returns immutable collections', () {
          final subject = IriTerm('http://example.org/resource');
          final predicate = IriTerm('http://example.org/property');
          final object = LiteralTerm.string('Value');
          final triple = Triple(subject, predicate, object);

          final graph = RdfGraph(triples: [triple]);
          final grouped = graph.groupByStorageIri();

          // Verify that the returned map is unmodifiable
          expect(() => grouped[IriTerm('newKey')] = [], throwsUnsupportedError);

          // Verify that the lists in the map are unmodifiable
          final storageIri = IriTerm('http://example.org/resource');
          expect(
            () => grouped[storageIri]!.add(triple),
            throwsUnsupportedError,
          );
        });

        test('handles empty graph', () {
          final graph = RdfGraph();
          final grouped = graph.groupByStorageIri();

          expect(grouped.isEmpty, isTrue);
        });
      });
    });

    // Legacy tests for compatibility verification
    group('Legacy Compatibility', () {
      test('should handle a complete profile', () {
        final profileTriple = Triple(
          IriTerm('https://example.com/profile#me'),
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
          IriTerm('http://www.w3.org/ns/solid/terms#Profile'),
        );
        final storageTriple1 = Triple(
          IriTerm('https://example.com/profile#me'),
          IriTerm('http://www.w3.org/ns/solid/terms#storage'),
          IriTerm('https://example.com/storage/'),
        );
        final storageTriple2 = Triple(
          IriTerm('https://example.com/profile#me'),
          IriTerm('http://www.w3.org/ns/pim/space#storage'),
          IriTerm('https://example.com/storage/'),
        );

        final graph = RdfGraph()
            .withTriple(profileTriple)
            .withTriple(storageTriple1)
            .withTriple(storageTriple2);

        // Find all storage URLs
        final storageTriples = graph
            .findTriples(subject: IriTerm('https://example.com/profile#me'))
            .where(
              (triple) =>
                  triple.predicate ==
                      IriTerm('http://www.w3.org/ns/solid/terms#storage') ||
                  triple.predicate ==
                      IriTerm('http://www.w3.org/ns/pim/space#storage'),
            );

        expect(storageTriples.length, equals(2));
        expect(
          storageTriples.map((t) => t.object),
          everyElement(equals(IriTerm('https://example.com/storage/'))),
        );
      });
    });
  });
}
