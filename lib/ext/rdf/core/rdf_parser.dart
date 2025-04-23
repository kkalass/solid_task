import 'package:logging/logging.dart';

import 'graph/rdf_graph.dart';
import 'plugin/format_plugin.dart';

/// Interface for parsing RDF documents in various formats
abstract interface class RdfParser {
  /// Parse an RDF document and return an RDF graph
  ///
  /// [input] is the RDF document to parse.
  /// [documentUrl] is the absolute URL of the document, used for resolving relative IRIs.
  /// If not provided, relative IRIs will be kept as-is.
  RdfGraph parse(String input, {String? documentUrl});
}

/// Interface for parser factories that create RDF parser instances
abstract interface class RdfParserFactoryBase {
  /// Creates a specialized RdfParser for a specific format.
  ///
  /// [contentType] MIME type that determines which parser to create.
  /// If null, returns an auto-detecting parser.
  RdfParser createParser({String? contentType});

  /// Directly parse an RDF document
  ///
  /// Convenience method that creates a parser and uses it to parse the input.
  RdfGraph parse(String input, {String? contentType, String? documentUrl});
}

/// Factory for creating RDF parsers based on content type.
///
/// This class follows the Factory pattern to create RdfParser implementations
/// based on content type and provides a direct parsing capability.
final class RdfParserFactory implements RdfParserFactoryBase {
  final _logger = Logger("rdf.parser.factory");
  final RdfFormatRegistry _registry;

  /// Creates a new parser factory using the specified registry
  RdfParserFactory(this._registry);

  @override
  RdfParser createParser({String? contentType}) {
    _logger.fine(
      'Creating parser for content type: ${contentType ?? "auto-detect"}',
    );
    return _registry.getParser(contentType);
  }

  @override
  RdfGraph parse(String input, {String? contentType, String? documentUrl}) {
    final parser = createParser(contentType: contentType);
    return parser.parse(input, documentUrl: documentUrl);
  }
}
