import 'package:logging/logging.dart';

import 'graph/rdf_graph.dart';
import '../turtle/turtle_parser.dart';
import '../jsonld/jsonld_parser.dart';

const _mimetypeTextTurtle = 'text/turtle';
const _mimetypeJsonLd = 'application/ld+json';
final _log = Logger("rdf.rdf_parser");

/// Interface for parsing RDF documents in various formats
abstract class RdfParser {
  /// Parse an RDF document and return an RDF graph
  ///
  /// [input] is the RDF document to parse.
  /// [documentUrl] is the absolute URL of the document, used for resolving relative IRIs.
  /// If not provided, relative IRIs will be kept as-is.
  RdfGraph parse(String input, {String? documentUrl});
}

/// Factory for creating RDF parsers based on content type.
///
/// This class follows the Factory pattern to create RdfParser implementations
/// based on content type and provides a direct parsing capability.
class RdfParserFactory {
  static final _logger = Logger("rdf.rdf_parser.factory");

  /// Creates a specialized RdfParser for a specific format.
  ///
  /// [contentType] MIME type that determines which parser to create.
  /// If null, returns an auto-detecting parser.
  RdfParser createParser({String? contentType}) {
    _logger.fine(
      'Creating parser for content type: ${contentType ?? "auto-detect"}',
    );

    if (contentType == null) {
      return _FormatDetectingParser(parserFactory: this);
    }

    final normalizedType = contentType.toLowerCase();

    if (normalizedType.contains(_mimetypeTextTurtle)) {
      return _TurtleParserAdapter();
    } else if (normalizedType.contains(_mimetypeJsonLd)) {
      return _JsonLdParserAdapter();
    }

    // Default to auto-detecting for unrecognized content types
    return _FormatDetectingParser(parserFactory: this);
  }
}

/// Parser adapter for Turtle format.
class _TurtleParserAdapter implements RdfParser {
  @override
  RdfGraph parse(String input, {String? documentUrl}) {
    _log.fine('Parsing with Turtle parser');
    final parser = TurtleParser(input, baseUri: documentUrl);
    return RdfGraph.fromTriples(parser.parse());
  }
}

/// Parser adapter for JSON-LD format.
class _JsonLdParserAdapter implements RdfParser {
  @override
  RdfGraph parse(String input, {String? documentUrl}) {
    _log.info('Parsing with JSON-LD parser');
    final parser = JsonLdParser(input, baseUri: documentUrl);
    return RdfGraph.fromTriples(parser.parse());
  }
}

/// Parser that detects format and delegates to appropriate implementation.
class _FormatDetectingParser implements RdfParser {
  final RdfParserFactory _parserFactory;

  _FormatDetectingParser({required RdfParserFactory parserFactory})
    : _parserFactory = parserFactory;

  @override
  RdfGraph parse(String input, {String? documentUrl}) {
    try {
      // Format detection logic
      _log.info('Attempting to auto-detect format from content');
      try {
        // Try JSON-LD first as it's easier to detect
        if (input.trim().startsWith('{') || input.trim().startsWith('[')) {
          _log.info('Content appears to be JSON-LD, trying JSON-LD parser');
          return _parserFactory
              .createParser(contentType: _mimetypeJsonLd)
              .parse(input, documentUrl: documentUrl);
        }
      } catch (e, stack) {
        _log.info('JSON-LD parsing failed during detection', e, stack);
      }

      // Fall back to Turtle
      _log.info('Falling back to Turtle parser');
      return _parserFactory
          .createParser(contentType: _mimetypeTextTurtle)
          .parse(input, documentUrl: documentUrl);
    } catch (e, stackTrace) {
      _log.info('Failed to parse RDF document', e, stackTrace);
      rethrow;
    }
  }
}
