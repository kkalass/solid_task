import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf/turtle/turtle_parser.dart';
import 'package:test/test.dart';

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
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.string('baz')));
    });

    test('should parse simple triples with escapes', () {
      final parser = TurtleParser(
        '<http://example.com/foo> <http://example.com/bar> "baz\\r\\nis\\"so cool\\" - or is \\\\ more cool? \\t \\b \\f" .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(
        triples[0].object,
        equals(
          LiteralTerm.string(
            'baz\r\nis"so cool" - or is \\ more cool? \t \b \f',
          ),
        ),
      );
    });

    test('should parse simple triples with boolean type', () {
      final parser = TurtleParser(
        '<http://example.com/foo> <http://example.com/bar> "baz"^^<http://www.w3.org/2001/XMLSchema#boolean> .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.typed('baz', 'boolean')));
    });

    test('should parse simple triples with boolean type and prefix', () {
      final parser = TurtleParser(
        '@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n'
        '<http://example.com/foo> <http://example.com/bar> "baz"^^xsd:boolean .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.typed('baz', 'boolean')));
    });

    test('should parse simple triples with language tag', () {
      final parser = TurtleParser(
        '<http://example.com/foo> <http://example.com/bar> "baz"@de .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.withLanguage('baz', 'de')));
    });

    test('should parse semicolon-separated triples', () {
      final parser = TurtleParser('''
        <http://example.com/foo> 
          <http://example.com/bar> "baz" ;
          <http://example.com/qux> "quux" .
        ''');
      final triples = parser.parse();
      expect(triples.length, equals(2));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.string('baz')));
      expect(triples[1].subject, equals(IriTerm('http://example.com/foo')));
      expect(triples[1].predicate, equals(IriTerm('http://example.com/qux')));
      expect(triples[1].object, equals(LiteralTerm.string('quux')));
    });

    test('should parse blank nodes', () {
      final parser = TurtleParser('[ <http://example.com/bar> "baz" ] .');
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, isA<BlankNodeTerm>());
      expect((triples[0].subject as BlankNodeTerm).label, startsWith('b'));
      expect(triples[0].predicate, equals(IriTerm('http://example.com/bar')));
      expect(triples[0].object, equals(LiteralTerm.string('baz')));
    });

    test('should parse type declarations', () {
      final parser = TurtleParser(
        '<http://example.com/foo> a <http://example.com/Bar> .',
      );
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(triples[0].subject, equals(IriTerm('http://example.com/foo')));
      expect(
        triples[0].predicate,
        equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')),
      );
      expect(triples[0].object, equals(IriTerm('http://example.com/bar')));
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
      expect(
        triples[0].subject,
        equals(IriTerm('https://example.com/profile#me')),
      );
      expect(
        triples[0].predicate,
        equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')),
      );
      expect(
        triples[0].object,
        equals(IriTerm('http://www.w3.org/ns/solid/terms#Profile')),
      );

      // Storage declarations
      expect(
        triples[1].subject,
        equals(IriTerm('https://example.com/profile#me')),
      );
      expect(
        triples[1].predicate,
        equals(IriTerm('http://www.w3.org/ns/solid/terms#storage')),
      );
      expect(
        triples[1].object,
        equals(IriTerm('https://example.com/storage/')),
      );

      expect(
        triples[2].subject,
        equals(IriTerm('https://example.com/profile#me')),
      );
      expect(
        triples[2].predicate,
        equals(IriTerm('http://www.w3.org/ns/pim/space#storage')),
      );
      expect(
        triples[2].object,
        equals(IriTerm('https://example.com/storage/')),
      );
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
      expect(
        triples[0].subject,
        equals(IriTerm('https://example.com/profile#me')),
      );
      expect(
        triples[0].predicate,
        equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')),
      );
      expect(
        triples[0].object,
        equals(IriTerm('http://www.w3.org/ns/solid/terms#Profile')),
      );

      // Check solid:storage
      expect(
        triples[1].subject,
        equals(IriTerm('https://example.com/profile#me')),
      );
      expect(
        triples[1].predicate,
        equals(IriTerm('http://www.w3.org/ns/solid/terms#storage')),
      );
      expect(
        triples[1].object,
        equals(IriTerm('https://example.com/storage/')),
      );

      // Check space:storage
      expect(
        triples[2].subject,
        equals(IriTerm('https://example.com/profile#me')),
      );
      expect(
        triples[2].predicate,
        equals(IriTerm('http://www.w3.org/ns/pim/space#storage')),
      );
      expect(
        triples[2].object,
        equals(IriTerm('https://example.com/storage/')),
      );
    });
  });
}
