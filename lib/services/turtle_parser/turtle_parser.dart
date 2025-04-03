import 'package:my_cross_platform_app/services/logger_service.dart';
import 'graph.dart';
import 'parser.dart';

/// Facade for parsing Turtle documents
class TurtleParserFacade {
  static final _logger = LoggerService();

  /// Parse a Turtle document and return an RDF graph
  static RdfGraph parse(String input) {
    try {
      final parser = TurtleParser(input);
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
  static List<String> findStorageUrls(String input) {
    try {
      final graph = parse(input);
      final storageTriples = graph.findTriples(
        predicate: 'http://www.w3.org/ns/solid/terms#storage',
      );

      final urls = <String>[];
      for (final triple in storageTriples) {
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
