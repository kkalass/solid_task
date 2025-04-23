import '../core/graph/rdf_graph.dart';
import '../core/plugin/format_plugin.dart';
import '../core/rdf_parser.dart';
import '../core/rdf_serializer.dart';
import 'jsonld_parser.dart';

/// RDF Format implementation for the JSON-LD serialization format.
///
/// JSON-LD provides a way to express linked data in JSON, allowing both humans and
/// machines to read and generate linked data with the familiar JSON syntax.
final class JsonLdFormat implements RdfFormat {
  static const _primaryMimeType = 'application/ld+json';

  static const _supportedMimeTypes = {_primaryMimeType, 'application/json+ld'};

  const JsonLdFormat();

  @override
  String get primaryMimeType => _primaryMimeType;

  @override
  Set<String> get supportedMimeTypes => _supportedMimeTypes;

  @override
  RdfParser createParser() => _JsonLdParserAdapter();

  @override
  RdfSerializer createSerializer() {
    throw FormatNotSupportedException('JSON-LD serializer not yet implemented');
  }

  @override
  bool canParse(String content) {
    // Simple heuristics for detecting JSON-LD format
    final trimmed = content.trim();

    // Must be valid JSON (starts with { or [)
    if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) {
      return false;
    }

    // Must contain at least one of these JSON-LD keywords
    return trimmed.contains('"@context"') ||
        trimmed.contains('"@id"') ||
        trimmed.contains('"@type"') ||
        trimmed.contains('"@graph"');
  }
}

/// Parser adapter for JSON-LD format
class _JsonLdParserAdapter implements RdfParser {
  @override
  RdfGraph parse(String input, {String? documentUrl}) {
    final parser = JsonLdParser(input, baseUri: documentUrl);
    return RdfGraph.fromTriples(parser.parse());
  }
}
