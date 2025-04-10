// lib/services/profile_parser.dart

import 'package:solid_task/services/logger_service.dart';

import '../rdf/rdf_graph.dart';
import '../rdf/rdf_parser.dart';

/// Interface for profile parsing operations
abstract class SolidProfileParser {
  /// Parse a profile document to extract the pod storage URL
  ///
  /// [webId] The WebID URL of the profile
  /// [content] The profile document content
  /// [contentType] The content type of the document
  Future<String?> parseStorageUrl(
    String webId,
    String content,
    String contentType,
  );
}

/// Implementation for parsing Solid profile documents
class DefaultSolidProfileParser implements SolidProfileParser {
  final ContextLogger _logger;
  final RdfParser _rdfParser;

  /// Common predicates used to identify storage locations in Solid profiles
  static const _storagePredicates = [
    'http://www.w3.org/ns/pim/space#storage',
    'http://www.w3.org/ns/solid/terms#storage',
    'http://www.w3.org/ns/ldp#contains',
    'http://www.w3.org/ns/solid/terms#oidcIssuer',
    'http://www.w3.org/ns/solid/terms#account',
    'http://www.w3.org/ns/solid/terms#storageLocation',
  ];

  /// Creates a new ProfileParser with the required dependencies
  DefaultSolidProfileParser({
    LoggerService? loggerService,
    RdfParser? rdfParser,
  }) : _logger = (loggerService ?? LoggerService()).createLogger(
         'DefaultProfileParser',
       ),
       _rdfParser = rdfParser ?? DefaultRdfParser(loggerService: loggerService);

  /// Find storage URLs in the parsed graph
  List<String> _findStorageUrls(RdfGraph graph) {
    try {
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

  @override
  Future<String?> parseStorageUrl(
    String webId,
    String content,
    String contentType,
  ) async {
    try {
      _logger.info('Parsing profile with content type: $contentType');

      // Use the unified RdfParser to handle both Turtle and JSON-LD
      try {
        final graph = _rdfParser.parse(
          content,
          contentType: contentType,
          documentUrl: webId,
        );

        final storageUrls = _findStorageUrls(graph);
        if (storageUrls.isNotEmpty) {
          _logger.info('Found storage URL: ${storageUrls.first}');
          return storageUrls.first;
        }

        // If no direct storage predicates were found, try other predicates
        for (final predicate in _storagePredicates) {
          final triples = graph.findTriples(predicate: predicate);
          if (triples.isNotEmpty) {
            final storageUrl = triples[0].object.replaceAll('"', '');
            _logger.info(
              'Found storage URL with alternative predicate: $storageUrl',
            );
            return storageUrl;
          }
        }

        _logger.warning('No storage URL found in profile document');
        return null;
      } catch (e, stackTrace) {
        _logger.error('RDF parsing failed', e, stackTrace);
        return null;
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to parse profile', e, stackTrace);
      return null;
    }
  }
}
