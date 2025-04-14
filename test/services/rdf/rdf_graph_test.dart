import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:solid_task/services/rdf/turtle/turtle_serializer.dart';
import 'package:test/test.dart';

void main() {
  group('RdfGraph', () {
    late RdfGraph graph;

    setUp(() {
      graph = RdfGraph();
    });

    test('langTerm', () {
      final langTerm = LiteralTerm.withLanguage('Hello', 'en');
      expect(
        langTerm.accept(RdfTermTurtleStringVisitor(prefixesByIri: {})),
        equals('"Hello"@en'),
      );
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
      expect(
        langTerm.accept(RdfTermTurtleStringVisitor(prefixesByIri: {})),
        equals('"Hello"@en'),
      );
    });
    test('should add and retrieve triples', () {
      final triple = Triple(
        IriTerm('http://example.com/foo'),
        IriTerm('http://example.com/bar'),
        LiteralTerm.string('baz'),
      );
      graph.addTriple(triple);

      final triples = graph.findTriples(
        subject: IriTerm('http://example.com/foo'),
        predicate: IriTerm('http://example.com/bar'),
        object: LiteralTerm.string('baz'),
      );
      expect(triples.length, equals(1));
      expect(triples[0], equals(triple));
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

      graph.addTriple(triple1);
      graph.addTriple(triple2);
      graph.addTriple(triple3);

      // Find by subject
      var triples = graph.findTriples(
        subject: IriTerm('http://example.com/foo'),
      );
      expect(triples.length, equals(2));
      expect(triples, contains(triple1));
      expect(triples, contains(triple2));

      // Find by predicate
      triples = graph.findTriples(predicate: IriTerm('http://example.com/bar'));
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

      graph.addTriple(profileTriple);
      graph.addTriple(storageTriple1);
      graph.addTriple(storageTriple2);

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
}
