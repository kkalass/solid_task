import 'package:solid_task/services/rdf/turtle/turtle_tokenizer.dart';
import 'package:test/test.dart';

void main() {
  group('TurtleTokenizer', () {
    test('should tokenize prefixes', () {
      final tokenizer = TurtleTokenizer(
        '@prefix solid: <http://www.w3.org/ns/solid/terms#> .',
      );
      expect(tokenizer.nextToken().type, equals(TokenType.prefix));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize IRIs', () {
      final tokenizer = TurtleTokenizer('<http://example.com/foo>');
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize blank nodes', () {
      final tokenizer = TurtleTokenizer('_:b1');
      expect(tokenizer.nextToken().type, equals(TokenType.blankNode));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize literals', () {
      final tokenizer = TurtleTokenizer('"Hello, World!"');
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize typed literals', () {
      final tokenizer = TurtleTokenizer(
        '"42"^^<http://www.w3.org/2001/XMLSchema#integer>',
      );
      final literalToken = tokenizer.nextToken();
      expect(literalToken.type, equals(TokenType.literal));
      expect(
        literalToken.value,
        equals('"42"^^<http://www.w3.org/2001/XMLSchema#integer>'),
      );
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize typed literals with prefixed name as type', () {
      final tokenizer = TurtleTokenizer('"42"^^xsd:integer');
      final literalToken = tokenizer.nextToken();
      expect(literalToken.type, equals(TokenType.literal));
      expect(literalToken.value, equals('"42"^^xsd:integer'));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize language-tagged literals', () {
      final tokenizer = TurtleTokenizer('"Hello"@en');
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize triples', () {
      final tokenizer = TurtleTokenizer(
        '<http://example.com/foo> <http://example.com/bar> "baz" .',
      );
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize blank node triples', () {
      final tokenizer = TurtleTokenizer('[ <http://example.com/bar> "baz" ] .');
      expect(tokenizer.nextToken().type, equals(TokenType.openBracket));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.closeBracket));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize semicolon-separated triples', () {
      final tokenizer = TurtleTokenizer(
        '<http://example.com/foo> <http://example.com/bar> "baz" ; <http://example.com/qux> "quux" .',
      );
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.semicolon));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.literal));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should tokenize a type declaration', () {
      final tokenizer = TurtleTokenizer(
        '<http://example.com/foo> a <http://example.com/Bar> .',
      );
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.a));
      expect(tokenizer.nextToken().type, equals(TokenType.iri));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });

    test('should not include dots in prefixed names', () {
      final tokenizer = TurtleTokenizer(
        'pro:card a foaf:PersonalProfileDocument; foaf:maker :me; foaf:primaryTopic :me.',
      );
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.a));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.semicolon));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.semicolon));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.prefixedName));
      expect(tokenizer.nextToken().type, equals(TokenType.dot));
      expect(tokenizer.nextToken().type, equals(TokenType.eof));
    });
  });
}
