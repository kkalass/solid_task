import 'package:solid_task/services/logger_service.dart';
import 'rdf_graph.dart';
import 'turtle/turtle_parser.dart';
import 'jsonld/jsonld_parser.dart';

/// Facade for parsing RDF documents in various formats
abstract class RdfParser {
  /// Parse an RDF document and return an RDF graph
  ///
  /// [input] is the RDF document to parse.
  /// [contentType] is the MIME type of the document, used to select the appropriate parser.
  /// If not provided, the method will attempt to detect the format.
  /// [documentUrl] is the absolute URL of the document, used for resolving relative IRIs.
  /// If not provided, relative IRIs will be kept as-is.
  RdfGraph parse(
    String input, {
    String? contentType,
    String? documentUrl,
  });
}

/// Default implementation of RdfParser
class DefaultRdfParser implements RdfParser {
  final ContextLogger _logger;
  final LoggerService? _loggerService;

  DefaultRdfParser({LoggerService? loggerService})
    : _loggerService = loggerService,
      _logger = (loggerService ?? LoggerService()).createLogger(
        "DefaultRdfParser",
      );

  /// Parse an RDF document and return an RDF graph
  ///
  /// This implementation supports Turtle and JSON-LD formats.
  /// The format is determined by the contentType parameter:
  /// - "text/turtle" for Turtle
  /// - "application/ld+json" for JSON-LD
  /// 
  /// If contentType is not provided or doesn't match a known format,
  /// this method will attempt to detect the format based on the content.
  /// 
  /// [input] is the RDF document to parse.
  /// [contentType] is the MIME type of the document.
  /// [documentUrl] is the absolute URL of the document, used for resolving relative IRIs.
  @override
  RdfGraph parse(
    String input, {
    String? contentType,
    String? documentUrl,
  }) {
    try {
      _logger.debug('Parsing RDF with content type: ${contentType ?? "unspecified"}');
      
      if (contentType != null) {
        // Try parsing with the specified content type
        if (contentType.contains('text/turtle')) {
          _logger.debug('Using Turtle parser based on content type');
          return _parseTurtle(input, documentUrl);
        } else if (contentType.contains('application/ld+json')) {
          _logger.debug('Using JSON-LD parser based on content type');
          return _parseJsonLd(input, documentUrl);
        }
        // If content type is specified but not supported, log warning
        _logger.warning('Unsupported content type: $contentType, will try format detection');
      }
      
      // Format detection logic
      _logger.debug('Attempting to auto-detect format');
      try {
        // Try JSON-LD first as it's easier to detect
        if (input.trim().startsWith('{') || input.trim().startsWith('[')) {
          _logger.debug('Content appears to be JSON-LD, trying JSON-LD parser');
          return _parseJsonLd(input, documentUrl);
        }
      } catch (e, stack) {
        _logger.debug('JSON-LD parsing failed during detection', e, stack);
      }
      
      // Fall back to Turtle
      _logger.debug('Falling back to Turtle parser');
      return _parseTurtle(input, documentUrl);
    } catch (e, stackTrace) {
      _logger.error('Failed to parse RDF document', e, stackTrace);
      rethrow;
    }
  }
  
  /// Helper method to parse Turtle format
  RdfGraph _parseTurtle(String input, String? documentUrl) {
    final parser = TurtleParser(
      input,
      baseUri: documentUrl,
      loggerService: _loggerService,
    );
    return RdfGraph.fromTriples(
      parser.parse(),
      loggerService: _loggerService,
    );
  }
  
  /// Helper method to parse JSON-LD format
  RdfGraph _parseJsonLd(String input, String? documentUrl) {
    final parser = JsonLdParser(
      input,
      baseUri: documentUrl,
      loggerService: _loggerService,
    );
    return RdfGraph.fromTriples(
      parser.parse(),
      loggerService: _loggerService,
    );
  }
}
