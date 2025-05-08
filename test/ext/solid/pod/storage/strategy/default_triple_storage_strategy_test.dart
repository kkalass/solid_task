import 'package:rdf_core/rdf_core.dart';
import 'package:test/test.dart';
import 'package:solid_task/ext/solid/pod/storage/strategy/default_triple_storage_strategy.dart';

void main() {
  group('DefaultTripleStorageStrategy', () {
    final strategy = DefaultTripleStorageStrategy();

    test('should extract document URL from IRI with fragment', () {
      final triple = Triple(
        IriTerm('https://pod.example.org/profile#me'),
        IriTerm('http://xmlns.com/foaf/0.1/name'),
        LiteralTerm.string('Alice'),
      );

      final result = strategy.getStorageIriForTriple(triple);
      expect(result.iri, equals('https://pod.example.org/profile'));
    });

    test('should preserve IRI without fragment', () {
      final triple = Triple(
        IriTerm('https://pod.example.org/data'),
        IriTerm('http://purl.org/dc/terms/created'),
        LiteralTerm.typed('2025-04-22', "datetime"),
      );

      final result = strategy.getStorageIriForTriple(triple);
      expect(result.iri, equals('https://pod.example.org/data'));
    });

    test('should handle blank node subjects with special IRI', () {
      final triple = Triple(
        BlankNodeTerm(),
        IriTerm('http://xmlns.com/foaf/0.1/name'),
        LiteralTerm.string('Unknown'),
      );

      final result = strategy.getStorageIriForTriple(triple);
      expect(result.iri, equals('tag:orphaned'));
    });

    test('should map triples to appropriate storage IRIs', () {
      final graph = RdfGraph(
        triples: [
          Triple(
            IriTerm('https://pod.example.org/profile#me'),
            IriTerm('http://xmlns.com/foaf/0.1/name'),
            LiteralTerm.string('Alice'),
          ),
          Triple(
            IriTerm('https://pod.example.org/profile#me'),
            IriTerm('http://xmlns.com/foaf/0.1/age'),
            LiteralTerm.typed('30', "integer"),
          ),
          Triple(
            IriTerm('https://pod.example.org/contacts#friend1'),
            IriTerm('http://xmlns.com/foaf/0.1/name'),
            LiteralTerm.string('Bob'),
          ),
        ],
      );

      final result = strategy.mapTriplesToStorage(graph);
      expect(result.keys.length, equals(2));
      expect(
        result.keys.map((k) => k.iri).toList()..sort(),
        equals([
          'https://pod.example.org/contacts',
          'https://pod.example.org/profile',
        ]),
      );
      expect(
        result[IriTerm('https://pod.example.org/profile')]?.length,
        equals(2),
      );
      expect(
        result[IriTerm('https://pod.example.org/contacts')]?.length,
        equals(1),
      );
    });

    test('should identify storage IRIs for a subject-based query', () {
      final result = strategy.getStorageIrisForQuery(
        subject: IriTerm('https://pod.example.org/profile#me'),
      );

      expect(result.length, equals(1));
      expect(result.first.iri, equals('https://pod.example.org/profile'));
    });

    test('should return empty list for non-subject queries', () {
      final result = strategy.getStorageIrisForQuery(
        predicate: IriTerm('http://xmlns.com/foaf/0.1/name'),
      );

      expect(result, isEmpty);
    });
  });
}
