import 'package:test/test.dart';
import 'package:solid_task/services/rdf/turtle/turtle_parser.dart';

void main() {
  group('TurtleParser', () {
    test('should parse prefixes', () {
      final parser = TurtleParser(
        '@prefix solid: <http://www.w3.org/ns/solid/terms#> .',
      );
      final triples = parser.parse();
      expect(triples, isEmpty);
    });

    test('should parse simple triples', () {
      final parser = TurtleParser(
        '<http://example.com/foo> <http://example.com/bar> "baz" .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals('http://example.com/foo'));
      expect(triples[0].predicate, equals('http://example.com/bar'));
      expect(triples[0].object, equals('baz'));
    });

    test('should parse semicolon-separated triples', () {
      final parser = TurtleParser('''
        <http://example.com/foo> 
          <http://example.com/bar> "baz" ;
          <http://example.com/qux> "quux" .
        ''');
      final triples = parser.parse();
      expect(triples.length, equals(2));
      expect(triples[0].subject, equals('http://example.com/foo'));
      expect(triples[0].predicate, equals('http://example.com/bar'));
      expect(triples[0].object, equals('baz'));
      expect(triples[1].subject, equals('http://example.com/foo'));
      expect(triples[1].predicate, equals('http://example.com/qux'));
      expect(triples[1].object, equals('quux'));
    });

    test('should parse blank nodes', () {
      final parser = TurtleParser('[ <http://example.com/bar> "baz" ] .');
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, startsWith('_:b'));
      expect(triples[0].predicate, equals('http://example.com/bar'));
      expect(triples[0].object, equals('baz'));
    });

    test('should parse type declarations', () {
      final parser = TurtleParser(
        '<http://example.com/foo> a <http://example.com/Bar> .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals('http://example.com/foo'));
      expect(
        triples[0].predicate,
        equals('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
      );
      expect(triples[0].object, equals('http://example.com/Bar'));
    });

    test('should reject using "a" as a subject', () {
      final parser = TurtleParser('a <http://example.com/bar> "baz" .');
      expect(() => parser.parse(), throwsFormatException);
    });

    test('should parse a complete profile', () {
      final parser = TurtleParser('''
        @prefix solid: <http://www.w3.org/ns/solid/terms#> .
        @prefix space: <http://www.w3.org/ns/pim/space#> .
        
        <https://example.com/profile#me>
          a solid:Profile ;
          solid:storage <https://example.com/storage/> ;
          space:storage <https://example.com/storage/> .
        ''');
      final triples = parser.parse();
      expect(triples.length, equals(3));

      // Type declaration
      expect(triples[0].subject, equals('https://example.com/profile#me'));
      expect(
        triples[0].predicate,
        equals('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
      );
      expect(
        triples[0].object,
        equals('http://www.w3.org/ns/solid/terms#Profile'),
      );

      // Storage declarations
      expect(triples[1].subject, equals('https://example.com/profile#me'));
      expect(
        triples[1].predicate,
        equals('http://www.w3.org/ns/solid/terms#storage'),
      );
      expect(triples[1].object, equals('https://example.com/storage/'));

      expect(triples[2].subject, equals('https://example.com/profile#me'));
      expect(
        triples[2].predicate,
        equals('http://www.w3.org/ns/pim/space#storage'),
      );
      expect(triples[2].object, equals('https://example.com/storage/'));
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

      final parser = TurtleParser(input);
      final triples = parser.parse();

      expect(triples.length, equals(3));

      // Check type declaration
      expect(triples[0].subject, equals('https://example.com/profile#me'));
      expect(
        triples[0].predicate,
        equals('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
      );
      expect(
        triples[0].object,
        equals('http://www.w3.org/ns/solid/terms#Profile'),
      );

      // Check solid:storage
      expect(triples[1].subject, equals('https://example.com/profile#me'));
      expect(
        triples[1].predicate,
        equals('http://www.w3.org/ns/solid/terms#storage'),
      );
      expect(triples[1].object, equals('https://example.com/storage/'));

      // Check space:storage
      expect(triples[2].subject, equals('https://example.com/profile#me'));
      expect(
        triples[2].predicate,
        equals('http://www.w3.org/ns/pim/space#storage'),
      );
      expect(triples[2].object, equals('https://example.com/storage/'));
    });
  });
}
