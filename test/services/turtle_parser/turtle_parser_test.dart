import 'package:test/test.dart';
import 'package:solid_task/services/turtle_parser/turtle_parser.dart';

void main() {
  group('TurtleParserFacade', () {
    test('should parse a simple profile', () {
      final input = '''
        @prefix solid: <http://www.w3.org/ns/solid/terms#> .
        @prefix space: <http://www.w3.org/ns/pim/space#> .
        
        <https://example.com/profile#me>
          a solid:Profile ;
          solid:storage <https://example.com/storage/> ;
          space:storage <https://example.com/storage/> .
      ''';

      final storageUrls = TurtleParserFacade.findStorageUrls(input);
      expect(storageUrls.length, equals(2));
      expect(storageUrls, everyElement(equals('https://example.com/storage/')));
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

      final storageUrls = TurtleParserFacade.findStorageUrls(
        input,
        documentUrl: 'https://kkalass.datapod.igrant.io/profile/card',
      );
      expect(storageUrls.length, equals(1));
      expect(
        storageUrls,
        everyElement(equals('https://kkalass.datapod.igrant.io/')),
      );
    });

    test('should handle multiple storage URLs', () {
      final input = '''
        @prefix solid: <http://www.w3.org/ns/solid/terms#> .
        
        <https://example.com/profile#me>
          solid:storage <https://example.com/storage1/> ;
          solid:storage <https://example.com/storage2/> .
      ''';

      final storageUrls = TurtleParserFacade.findStorageUrls(input);
      expect(storageUrls.length, equals(2));
      expect(storageUrls, contains('https://example.com/storage1/'));
      expect(storageUrls, contains('https://example.com/storage2/'));
    });

    test('should handle blank nodes', () {
      final input = '''
        @prefix solid: <http://www.w3.org/ns/solid/terms#> .
        
        <https://example.com/profile#me>
          solid:storage [
            solid:location <https://example.com/storage/>
          ] .
      ''';

      final storageUrls = TurtleParserFacade.findStorageUrls(input);
      expect(storageUrls.length, equals(1));
      expect(storageUrls[0], equals('https://example.com/storage/'));
    });

    test('should handle type declarations', () {
      final input = '''
        @prefix solid: <http://www.w3.org/ns/solid/terms#> .
        
        <https://example.com/profile#me>
          a solid:Profile ;
          solid:storage <https://example.com/storage/> .
      ''';

      final storageUrls = TurtleParserFacade.findStorageUrls(input);
      expect(storageUrls.length, equals(1));
      expect(storageUrls[0], equals('https://example.com/storage/'));
    });

    test('should handle complex profiles', () {
      final input = '''
        @prefix solid: <http://www.w3.org/ns/solid/terms#> .
        @prefix space: <http://www.w3.org/ns/pim/space#> .
        @prefix foaf: <http://xmlns.com/foaf/0.1/> .
        
        <https://example.com/profile#me>
          a solid:Profile ;
          foaf:name "John Doe" ;
          solid:storage <https://example.com/storage/> ;
          space:storage <https://example.com/storage/> ;
          foaf:knows [
            a foaf:Person ;
            foaf:name "Jane Smith"
          ] .
      ''';

      final storageUrls = TurtleParserFacade.findStorageUrls(input);
      expect(storageUrls.length, equals(2));
      expect(storageUrls, everyElement(equals('https://example.com/storage/')));
    });
  });
}
