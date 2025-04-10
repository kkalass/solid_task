import 'package:solid_task/services/logger_service.dart';
import 'graph.dart';
import 'parser.dart';

/// Facade for parsing Turtle documents
abstract class TurtleParserFacade {
  /// Find storage URLs in a Turtle document
  List<String> findStorageUrls(String content, {String? documentUrl});
}

/// Default implementation of TurtleParserFacade
class DefaultTurtleParser implements TurtleParserFacade {
  final ContextLogger _logger;
  final LoggerService? _loggerService;

  DefaultTurtleParser({LoggerService? loggerService})
    : _loggerService = loggerService,
      _logger = (loggerService ?? LoggerService()).createLogger(
        "DefaultTurtleParser",
      );

  /// Parse a Turtle document and return an RDF graph
  ///
  /// [input] is the Turtle document to parse.
  /// [documentUrl] is the absolute URL of the document, used for resolving relative IRIs.
  /// If not provided, relative IRIs will be kept as-is.
  RdfGraph parse(String input, {String? documentUrl}) {
    try {
      final parser = TurtleParser(
        input,
        baseUri: documentUrl,
        loggerService: _loggerService,
      );
      final triples = parser.parse();

      final graph = RdfGraph();
      for (final triple in triples) {
        graph.addTriple(
          Triple(
            graph.expandIri(triple.subject),
            graph.expandIri(triple.predicate),
            graph.expandIri(triple.object),
          ),
        );
      }

      return graph;
    } catch (e, stackTrace) {
      _logger.error('Failed to parse Turtle document', e, stackTrace);
      rethrow;
    }
  }

  @override
  List<String> findStorageUrls(String content, {String? documentUrl}) {
    try {
      final graph = parse(content, documentUrl: documentUrl);
      final storageTriples = graph.findTriples(
        predicate: 'http://www.w3.org/ns/solid/terms#storage',
      );
      final spaceStorageTriples = graph.findTriples(
        predicate: 'http://www.w3.org/ns/pim/space#storage',
      );

      final urls = <String>[];
      for (final triple in [...storageTriples, ...spaceStorageTriples]) {
        if (triple.object.startsWith('_:')) {
          // If the storage points to a blank node, look for location triples
          final locationTriples = graph.findTriples(
            subject: triple.object,
            predicate: 'http://www.w3.org/ns/solid/terms#location',
          );
          for (final locationTriple in locationTriples) {
            urls.add(locationTriple.object);
          }
        } else {
          urls.add(triple.object);
        }
      }

      return urls;
    } catch (e, stackTrace) {
      _logger.error('Failed to find storage URLs', e, stackTrace);
      rethrow;
    }
  }
}
