import 'package:solid_task/services/rdf/rdf_parser.dart';
import 'package:test/test.dart';

void main() {
  group('RdfParser', () {
    late RdfParser rdfParser;

    setUp(() {
      rdfParser = DefaultRdfParser();
    });

    test('should parse a simple profile', () {
      final input = '''
        @prefix solid: <http://www.w3.org/ns/solid/terms#> .
        @prefix space: <http://www.w3.org/ns/pim/space#> .
        
        <https://example.com/profile#me>
          a solid:Profile ;
          solid:storage <https://example.com/storage/> ;
          space:storage <https://example.com/storage/> .
      ''';

      final graph = rdfParser.parse(
        input,
        documentUrl: 'https://example.com/profile#me',
      );

      // Verify graph structure
      expect(graph.triples.length, equals(3));

      // Check for solid:storage triple
      final solidStorageTriples = graph.findTriples(
        subject: 'https://example.com/profile#me',
        predicate: 'http://www.w3.org/ns/solid/terms#storage',
      );
      expect(solidStorageTriples.length, equals(1));
      expect(
        solidStorageTriples.first.object,
        equals('https://example.com/storage/'),
      );

      // Check for space:storage triple
      final spaceStorageTriples = graph.findTriples(
        subject: 'https://example.com/profile#me',
        predicate: 'http://www.w3.org/ns/pim/space#storage',
      );
      expect(spaceStorageTriples.length, equals(1));
      expect(
        spaceStorageTriples.first.object,
        equals('https://example.com/storage/'),
      );
    });

    test('should parse a real life profile', () {
      final input = '''
@prefix : <#>.
@prefix acl: <http://www.w3.org/ns/auth/acl#>.
@prefix foaf: <http://xmlns.com/foaf/0.1/>.
@prefix ldp: <http://www.w3.org/ns/ldp#>.
@prefix schema: <http://schema.org/>.
@prefix solid: <http://www.w3.org/ns/solid/terms#>.
@prefix space: <http://www.w3.org/ns/pim/space#>.
@prefix pro: <./>.
@prefix inbox: </inbox/>.
@prefix kk: </>.

pro:card a foaf:PersonalProfileDocument; foaf:maker :me; foaf:primaryTopic :me.

:me
    a schema:Person, foaf:Person;
    acl:trustedApp
            [
                acl:mode acl:Append, acl:Read, acl:Write;
                acl:origin <http://localhost:4400>
            ],
            [
                acl:mode acl:Append, acl:Read, acl:Write;
                acl:origin <http://localhost:52927>
            ];
    ldp:inbox inbox:;
    space:preferencesFile </settings/prefs.ttl>;
    space:storage kk:;
    solid:account kk:;
    solid:oidcIssuer <https://datapod.igrant.io>;
    solid:privateTypeIndex </settings/privateTypeIndex.ttl>;
    solid:publicTypeIndex </settings/publicTypeIndex.ttl>;
    foaf:name "Klas Kala\u00df".
      ''';

      final graph = rdfParser.parse(
        input,
        documentUrl: 'https://kkalass.datapod.igrant.io/profile/card',
      );

      // Verify solid:account triple
      final solidAccountTriples = graph.findTriples(
        subject: 'https://kkalass.datapod.igrant.io/profile/card#me',
        predicate: 'http://www.w3.org/ns/solid/terms#account',
      );
      expect(solidAccountTriples.length, equals(1));
      expect(
        solidAccountTriples.first.object,
        equals('https://kkalass.datapod.igrant.io/'),
      );

      // Verify space:storage triple
      final spaceStorageTriples = graph.findTriples(
        subject: 'https://kkalass.datapod.igrant.io/profile/card#me',
        predicate: 'http://www.w3.org/ns/pim/space#storage',
      );
      expect(spaceStorageTriples.length, equals(1));
      expect(
        spaceStorageTriples.first.object,
        equals('https://kkalass.datapod.igrant.io/'),
      );

      // Verify foaf:name triple
      final nameTriples = graph.findTriples(
        subject: 'https://kkalass.datapod.igrant.io/profile/card#me',
        predicate: 'http://xmlns.com/foaf/0.1/name',
      );
      expect(nameTriples.length, equals(1));
      expect(nameTriples.first.object, equals('Klas Kalaß'));
    });

    test('should handle multiple triples with the same predicate', () {
      final input = '''
        @prefix solid: <http://www.w3.org/ns/solid/terms#> .
        
        <https://example.com/profile#me>
          solid:storage <https://example.com/storage1/> ;
          solid:storage <https://example.com/storage2/> .
      ''';

      final graph = rdfParser.parse(input);

      // Find all storage triples
      final storageTriples = graph.findTriples(
        subject: 'https://example.com/profile#me',
        predicate: 'http://www.w3.org/ns/solid/terms#storage',
      );

      expect(storageTriples.length, equals(2));

      // Extract all storage URLs
      final storageUrls =
          storageTriples.map((triple) => triple.object).toList();
      expect(storageUrls, contains('https://example.com/storage1/'));
      expect(storageUrls, contains('https://example.com/storage2/'));
    });

    test('should handle type declarations', () {
      final input = '''
        @prefix solid: <http://www.w3.org/ns/solid/terms#> .
        @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
        
        <https://example.com/profile#me>
          rdf:type solid:Profile ;
          solid:storage <https://example.com/storage/> .
      ''';

      final graph = rdfParser.parse(input);

      // Verify type declaration
      final typeTriples = graph.findTriples(
        subject: 'https://example.com/profile#me',
        predicate: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
      );
      expect(typeTriples.length, equals(1));
      expect(
        typeTriples.first.object,
        equals('http://www.w3.org/ns/solid/terms#Profile'),
      );

      // Verify storage triple
      final storageTriples = graph.findTriples(
        subject: 'https://example.com/profile#me',
        predicate: 'http://www.w3.org/ns/solid/terms#storage',
      );
      expect(storageTriples.length, equals(1));
      expect(
        storageTriples.first.object,
        equals('https://example.com/storage/'),
      );
    });

    test('should parse complex profiles with different triple patterns', () {
      final input = '''
        @prefix solid: <http://www.w3.org/ns/solid/terms#> .
        @prefix space: <http://www.w3.org/ns/pim/space#> .
        @prefix foaf: <http://xmlns.com/foaf/0.1/> .
        @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
        
        <https://example.com/profile#me>
          rdf:type solid:Profile ;
          foaf:name "John Doe" ;
          solid:storage <https://example.com/storage/> ;
          space:storage <https://example.com/storage/> ;
          foaf:knows [
            rdf:type foaf:Person ;
            foaf:name "Jane Smith"
          ] .
      ''';

      final graph = rdfParser.parse(input);

      // Verify profile type
      final profileTypeTriples = graph.findTriples(
        subject: 'https://example.com/profile#me',
        predicate: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
      );
      expect(profileTypeTriples.length, equals(1));

      // Verify storage triples
      final solidStorageTriples = graph.findTriples(
        subject: 'https://example.com/profile#me',
        predicate: 'http://www.w3.org/ns/solid/terms#storage',
      );
      expect(solidStorageTriples.length, equals(1));

      final spaceStorageTriples = graph.findTriples(
        subject: 'https://example.com/profile#me',
        predicate: 'http://www.w3.org/ns/pim/space#storage',
      );
      expect(spaceStorageTriples.length, equals(1));

      // Verify name triple
      final nameTriples = graph.findTriples(
        subject: 'https://example.com/profile#me',
        predicate: 'http://xmlns.com/foaf/0.1/name',
      );
      expect(nameTriples.length, equals(1));
      expect(nameTriples.first.object, equals('John Doe'));

      // Check total triples count (should include blank node triples)
      expect(graph.triples.length > 5, isTrue);
    });
  });
}
