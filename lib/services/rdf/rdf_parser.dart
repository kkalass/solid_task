import 'package:solid_task/services/logger_service.dart';
import 'rdf_graph.dart';
import 'turtle/turtle_parser.dart';
import 'jsonld/jsonld_parser.dart';

const _mimetypeTextTurtle = 'text/turtle';
const _mimetypeJsonLd = 'application/ld+json';

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
  final LoggerService? _loggerService;
  final ContextLogger _logger;

  RdfParserFactory({LoggerService? loggerService})
    : _loggerService = loggerService,
      _logger = (loggerService ?? LoggerService()).createLogger(
        'RdfParserFactory',
      );

  /// Creates a specialized RdfParser for a specific format.
  ///
  /// [contentType] MIME type that determines which parser to create.
  /// If null, returns an auto-detecting parser.
  RdfParser createParser({String? contentType}) {
    _logger.debug(
      'Creating parser for content type: ${contentType ?? "auto-detect"}',
    );

    if (contentType == null) {
      return _FormatDetectingParser(
        parserFactory: this,
        loggerService: _loggerService,
      );
    }

    final normalizedType = contentType.toLowerCase();

    if (normalizedType.contains(_mimetypeTextTurtle)) {
      return _TurtleParserAdapter(loggerService: _loggerService);
    } else if (normalizedType.contains(_mimetypeJsonLd)) {
      return _JsonLdParserAdapter(loggerService: _loggerService);
    }

    // Default to auto-detecting for unrecognized content types
    return _FormatDetectingParser(
      parserFactory: this,
      loggerService: _loggerService,
    );
  }
}

/// Parser adapter for Turtle format.
class _TurtleParserAdapter implements RdfParser {
  final LoggerService? _loggerService;
  final ContextLogger _logger;

  _TurtleParserAdapter({LoggerService? loggerService})
    : _loggerService = loggerService,
      _logger = (loggerService ?? LoggerService()).createLogger(
        "TurtleParserAdapter",
      );

  @override
  RdfGraph parse(String input, {String? documentUrl}) {
    _logger.debug('Parsing with Turtle parser');
    final parser = TurtleParser(
      input,
      baseUri: documentUrl,
      loggerService: _loggerService,
    );
    return RdfGraph.fromTriples(parser.parse());
  }
}

/// Parser adapter for JSON-LD format.
class _JsonLdParserAdapter implements RdfParser {
  final LoggerService? _loggerService;
  final ContextLogger _logger;

  _JsonLdParserAdapter({LoggerService? loggerService})
    : _loggerService = loggerService,
      _logger = (loggerService ?? LoggerService()).createLogger(
        "JsonLdParserAdapter",
      );

  @override
  RdfGraph parse(String input, {String? documentUrl}) {
    _logger.debug('Parsing with JSON-LD parser');
    final parser = JsonLdParser(
      input,
      baseUri: documentUrl,
      loggerService: _loggerService,
    );
    return RdfGraph.fromTriples(parser.parse());
  }
}

/// Parser that detects format and delegates to appropriate implementation.
class _FormatDetectingParser implements RdfParser {
  final RdfParserFactory _parserFactory;
  final ContextLogger _logger;

  _FormatDetectingParser({
    required RdfParserFactory parserFactory,
    LoggerService? loggerService,
  }) : _parserFactory = parserFactory,
       _logger = (loggerService ?? LoggerService()).createLogger(
         "FormatDetectingParser",
       );

  @override
  RdfGraph parse(String input, {String? documentUrl}) {
    try {
      // Format detection logic
      _logger.debug('Attempting to auto-detect format from content');
      try {
        // Try JSON-LD first as it's easier to detect
        if (input.trim().startsWith('{') || input.trim().startsWith('[')) {
          _logger.debug('Content appears to be JSON-LD, trying JSON-LD parser');
          return _parserFactory
              .createParser(contentType: _mimetypeJsonLd)
              .parse(input, documentUrl: documentUrl);
        }
      } catch (e, stack) {
        _logger.debug('JSON-LD parsing failed during detection', e, stack);
      }

      // Fall back to Turtle
      _logger.debug('Falling back to Turtle parser');
      return _parserFactory
          .createParser(contentType: _mimetypeTextTurtle)
          .parse(input, documentUrl: documentUrl);
    } catch (e, stackTrace) {
      _logger.error('Failed to parse RDF document', e, stackTrace);
      rethrow;
    }
  }
}
