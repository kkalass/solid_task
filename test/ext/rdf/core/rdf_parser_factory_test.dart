import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/ext/rdf/core/constants/rdf_constants.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_graph.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf/core/rdf_parser.dart';

void main() {
  group('RdfParserFactory', () {
    late RdfParserFactory factory;

    setUp(() {
      factory = RdfParserFactory();
    });

    test('should create Turtle parser for text/turtle content type', () {
      final parser = factory.createParser(contentType: 'text/turtle');

      // Verify it's a Turtle parser by parsing some Turtle content
      final input =
          '<http://example.org/subject> <http://example.org/predicate> "object" .';
      final graph = parser.parse(input);

      expect(graph.size, equals(1));
      expect(
        graph.triples[0].subject,
        equals(IriTerm('http://example.org/subject')),
      );
      expect(
        graph.triples[0].predicate,
        equals(IriTerm('http://example.org/predicate')),
      );
    });

    test(
      'should create JSON-LD parser for application/ld+json content type',
      () {
        final parser = factory.createParser(contentType: 'application/ld+json');

        // Verify it's a JSON-LD parser by parsing some JSON-LD content
        final input = '''
      {
        "@id": "http://example.org/subject",
        "http://example.org/predicate": "object"
      }
      ''';
        final graph = parser.parse(input);

        expect(graph.size, equals(1));
        expect(
          graph.triples[0].subject,
          equals(IriTerm('http://example.org/subject')),
        );
        expect(
          graph.triples[0].predicate,
          equals(IriTerm('http://example.org/predicate')),
        );
      },
    );

    test('should handle content type variants with parameters', () {
      final parser = factory.createParser(
        contentType: 'text/turtle; charset=UTF-8',
      );

      // Verify it's correctly identified as Turtle
      final input = '<http://example.org/s> <http://example.org/p> "o" .';
      final graph = parser.parse(input);

      expect(graph.size, equals(1));
    });

    test('should auto-detect JSON-LD format', () {
      // Create auto-detecting parser
      final parser = factory.createParser();

      // Parse JSON-LD content
      final input = '''
      {
        "@id": "http://example.org/subject",
        "http://example.org/predicate": "object"
      }
      ''';
      final graph = parser.parse(input);

      expect(graph.size, equals(1));
      expect(
        graph.triples[0].subject,
        equals(IriTerm('http://example.org/subject')),
      );
    });

    test('should auto-detect array-based JSON-LD format', () {
      // Create auto-detecting parser
      final parser = factory.createParser();

      // Parse array-based JSON-LD content
      final input = '''
      [
        {
          "@id": "http://example.org/subject",
          "http://example.org/predicate": "object"
        }
      ]
      ''';
      final graph = parser.parse(input);

      expect(graph.size, equals(1));
      expect(
        graph.triples[0].subject,
        equals(IriTerm('http://example.org/subject')),
      );
    });

    test('should fall back to Turtle parser for ambiguous content', () {
      // Create auto-detecting parser
      final parser = factory.createParser();

      // Parse Turtle content that doesn't look like JSON
      final input =
          '@prefix ex: <http://example.org/> .\nex:subject ex:predicate "object" .';
      final graph = parser.parse(input);

      expect(graph.size, equals(1));
      expect(
        graph.triples[0].subject,
        equals(IriTerm('http://example.org/subject')),
      );
    });

    test('should handle Turtle with base URI for resolving relative IRIs', () {
      final parser = factory.createParser(contentType: 'text/turtle');

      final input = '<subject> <predicate> <object> .';
      final graph = parser.parse(input, documentUrl: 'http://example.org/');

      expect(graph.size, equals(1));
      expect(
        graph.triples[0].subject,
        equals(IriTerm('http://example.org/subject')),
      );
      expect(
        graph.triples[0].predicate,
        equals(IriTerm('http://example.org/predicate')),
      );
      expect(
        graph.triples[0].object,
        equals(IriTerm('http://example.org/object')),
      );
    });

    test('should handle JSON-LD with base URI for resolving relative IRIs', () {
      final parser = factory.createParser(contentType: 'application/ld+json');

      final input = '''
      {
        "@id": "subject",
        "predicate": {"@id": "object"}
      }
      ''';
      final graph = parser.parse(input, documentUrl: 'http://example.org/');

      expect(graph.size, equals(1));
      expect(
        graph.triples[0].subject,
        equals(IriTerm('http://example.org/subject')),
      );
      // JSON-LD handles the predicate expansion differently, it doesn't
      // automatically expand unqualified predicates against the base URI
      expect(
        graph.triples[0].object,
        equals(IriTerm('http://example.org/object')),
      );
    });

    test('should throw exception for unparsable content', () {
      final parser = factory.createParser();

      // Neither valid Turtle nor JSON-LD
      final input = 'This is not a valid RDF document.';

      expect(() => parser.parse(input), throwsException);
    });

    test('should handle minimal edge cases', () {
      final parser = factory.createParser();

      // Empty document
      expect(parser.parse('').isEmpty, isTrue);

      // Just whitespace
      expect(parser.parse('   \n\t  ').isEmpty, isTrue);
    });
  });
}
