import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:solid_task/services/rdf/turtle/turtle_writer.dart';

void main() {
  group('TurtleWriter', () {
    test('writes prefixes correctly', () {
      final writer = TurtleWriter(
        prefixes: {
          'ex': 'http://example.org/',
          'test': 'http://test.org/',
        },
      );
      
      final graph = RdfGraph();
      
      final output = writer.write(graph);
      
      expect(output, contains('@prefix ex: <http://example.org/> .'));
      expect(output, contains('@prefix test: <http://test.org/> .'));
    });
    
    test('writes base URI if provided', () {
      final writer = TurtleWriter(baseUri: 'http://base.org/');
      final graph = RdfGraph();
      
      final output = writer.write(graph);
      
      expect(output, contains('@base <http://base.org/> .'));
    });
    
    test('formats triples correctly', () {
      final writer = TurtleWriter();
      final graph = RdfGraph();
      
      graph.addTriple(Triple(
        'http://example.org/subject',
        'http://example.org/predicate',
        'http://example.org/object',
      ));
      
      final output = writer.write(graph);
      
      expect(output, contains('<http://example.org/subject> <http://example.org/predicate> <http://example.org/object> .'));
    });
    
    test('groups triples by subject', () {
      final writer = TurtleWriter();
      final graph = RdfGraph();
      
      // Two triples with same subject
      graph.addTriple(Triple(
        'http://example.org/subject',
        'http://example.org/predicate1',
        'http://example.org/object1',
      ));
      
      graph.addTriple(Triple(
        'http://example.org/subject',
        'http://example.org/predicate2',
        'http://example.org/object2',
      ));
      
      final output = writer.write(graph);
      
      // The output should have the subject only once
      final subjectMatches = RegExp('<http://example.org/subject>').allMatches(output);
      expect(subjectMatches.length, equals(1), reason: 'Subject should appear only once');
      
      // And should use semicolons to separate predicates
      expect(output, contains(';'));
    });
    
    test('formats literals correctly', () {
      final writer = TurtleWriter();
      final graph = RdfGraph();
      
      // String literal
      graph.addTriple(Triple(
        'http://example.org/subject',
        'http://example.org/stringProp',
        'This is a string',
      ));
      
      // Number literal
      graph.addTriple(Triple(
        'http://example.org/subject',
        'http://example.org/numberProp',
        '42',
      ));
      
      // Boolean literal
      graph.addTriple(Triple(
        'http://example.org/subject',
        'http://example.org/boolProp',
        'true',
      ));
      
      final output = writer.write(graph);
      
      // String should be quoted
      expect(output, contains('"This is a string"'));
      
      // Number should not be quoted
      expect(output, contains('42'));
      
      // Boolean should not be quoted
      expect(output, contains('true'));
    });
    
    test('escapes special characters in string literals', () {
      final writer = TurtleWriter();
      final graph = RdfGraph();
      
      graph.addTriple(Triple(
        'http://example.org/subject',
        'http://example.org/predicate',
        'String with "quotes" and \\ backslash and \n newline',
      ));
      
      final output = writer.write(graph);
      
      // Quotes, backslashes and newlines should be escaped
      expect(output, contains('"String with \\"quotes\\" and \\\\ backslash and \\n newline"'));
    });
    
    test('uses prefixes to abbreviate URIs when possible', () {
      final writer = TurtleWriter(
        prefixes: {
          'ex': 'http://example.org/',
        },
      );
      
      final graph = RdfGraph();
      
      graph.addTriple(Triple(
        'http://example.org/subject',
        'http://example.org/predicate',
        'http://example.org/object',
      ));
      
      final output = writer.write(graph);
      
      // The URIs should be abbreviated using the prefix
      expect(output, contains('ex:subject ex:predicate ex:object .'));
    });
  });
}