import 'package:solid_task/services/logger_service.dart';
import 'graph.dart';
import 'parser.dart';

/// Facade for parsing Turtle documents
class TurtleParserFacade {
  static final _logger = LoggerService();

  /// Parse a Turtle document and return an RDF graph
  ///
  /// [input] is the Turtle document to parse.
  /// [documentUrl] is the absolute URL of the document, used for resolving relative IRIs.
  /// If not provided, relative IRIs will be kept as-is.
  static RdfGraph parse(String input, {String? documentUrl}) {
    try {
      final parser = TurtleParser(input, baseUri: documentUrl);
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

  /// Find storage URLs in a Turtle document
  ///
  /// [input] is the Turtle document to parse.
  /// [documentUrl] is the absolute URL of the document, used for resolving relative IRIs.
  /// If not provided, relative IRIs will be kept as-is.
  static List<String> findStorageUrls(String input, {String? documentUrl}) {
    try {
      final graph = parse(input, documentUrl: documentUrl);
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
