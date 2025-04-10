import 'package:solid_task/services/logger_service.dart';
import 'rdf_graph.dart';
import 'turtle/turtle_parser.dart';

/// Facade for parsing Turtle documents
abstract class RdfParser {
  /// Parse a Turtle document and return an RDF graph
  ///
  /// [input] is the Turtle document to parse.
  /// [documentUrl] is the absolute URL of the document, used for resolving relative IRIs.
  /// If not provided, relative IRIs will be kept as-is.
  RdfGraph parse(String input, {String? documentUrl});
}

/// Default implementation of TurtleParserFacade
class DefaultRdfParser implements RdfParser {
  final ContextLogger _logger;
  final LoggerService? _loggerService;

  DefaultRdfParser({LoggerService? loggerService})
    : _loggerService = loggerService,
      _logger = (loggerService ?? LoggerService()).createLogger(
        "DefaultTurtleParser",
      );

  /// Parse a Turtle document and return an RDF graph
  ///
  /// [input] is the Turtle document to parse.
  /// [documentUrl] is the absolute URL of the document, used for resolving relative IRIs.
  /// If not provided, relative IRIs will be kept as-is.
  @override
  RdfGraph parse(String input, {String? documentUrl}) {
    try {
      final parser = TurtleParser(
        input,
        baseUri: documentUrl,
        loggerService: _loggerService,
      );
      return RdfGraph.fromTriples(
        parser.parse(),
        loggerService: _loggerService,
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to parse Turtle document', e, stackTrace);
      rethrow;
    }
  }
}
