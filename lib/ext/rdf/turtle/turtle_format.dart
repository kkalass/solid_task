import '../core/graph/rdf_graph.dart';
import '../core/plugin/format_plugin.dart';
import '../core/rdf_parser.dart';
import '../core/rdf_serializer.dart';
import 'turtle_parser.dart';
import 'turtle_serializer.dart';

/// RDF Format implementation for the Turtle serialization format.
///
/// Turtle (Terse RDF Triple Language) provides a textual syntax for RDF that is
/// both readable and writable by humans while being easy to parse by machines.
final class TurtleFormat implements RdfFormat {
  static const _primaryMimeType = 'text/turtle';

  static const _supportedMimeTypes = {
    _primaryMimeType,
    'application/x-turtle',
    'application/turtle',
    'text/n3', // N3 is a superset of Turtle
    'text/rdf+n3', // Alternative MIME for N3
    'application/rdf+n3', // Alternative MIME for N3
  };

  const TurtleFormat();

  @override
  String get primaryMimeType => _primaryMimeType;

  @override
  Set<String> get supportedMimeTypes => _supportedMimeTypes;

  @override
  RdfParser createParser() => _TurtleParserAdapter();

  @override
  RdfSerializer createSerializer() => TurtleSerializer();

  @override
  bool canParse(String content) {
    // Simple heuristics for detecting Turtle format
    final trimmed = content.trim();

    // Check for common Turtle prefixes, predicates or statements
    return trimmed.contains('@prefix') ||
        trimmed.contains('@base') ||
        // Look for triple pattern ending with dot
        RegExp(r'.*\s+.*\s+.*\s*\.$', multiLine: true).hasMatch(trimmed) ||
        // Check for common RDF prefix declarations
        trimmed.contains('prefix rdf:') ||
        trimmed.contains('prefix rdfs:') ||
        trimmed.contains('prefix owl:') ||
        trimmed.contains('prefix xsd:');
  }
}

/// Parser adapter for Turtle format
class _TurtleParserAdapter implements RdfParser {
  @override
  RdfGraph parse(String input, {String? documentUrl}) {
    final parser = TurtleParser(input, baseUri: documentUrl);
    return RdfGraph.fromTriples(parser.parse());
  }
}
