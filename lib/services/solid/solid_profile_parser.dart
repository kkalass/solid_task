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
  final RdfParserFactory _rdfParserFactory;

  /// Common predicates used to identify storage locations in Solid profiles
  static const _storagePredicates = [
    IriTerm('http://www.w3.org/ns/pim/space#storage'),
    IriTerm('http://www.w3.org/ns/solid/terms#storage'),
    IriTerm('http://www.w3.org/ns/ldp#contains'),
    IriTerm('http://www.w3.org/ns/solid/terms#oidcIssuer'),
    IriTerm('http://www.w3.org/ns/solid/terms#account'),
    IriTerm('http://www.w3.org/ns/solid/terms#storageLocation'),
  ];

  /// Creates a new ProfileParser with the required dependencies
  DefaultSolidProfileParser({
    LoggerService? loggerService,
    RdfParserFactory? rdfParserFactory,
  }) : _logger = (loggerService ?? LoggerService()).createLogger(
         'DefaultProfileParser',
       ),
       _rdfParserFactory =
           rdfParserFactory ?? RdfParserFactory(loggerService: loggerService);

  /// Find storage URLs in the parsed graph
  List<String> _findStorageUrls(RdfGraph graph) {
    try {
      final storageTriples = graph.findTriples(
        predicate: IriTerm('http://www.w3.org/ns/solid/terms#storage'),
      );
      final spaceStorageTriples = graph.findTriples(
        predicate: IriTerm('http://www.w3.org/ns/pim/space#storage'),
      );

      final urls = <String>[];
      for (final triple in [...storageTriples, ...spaceStorageTriples]) {
        _addIri(triple, urls, graph);
      }

      return urls;
    } catch (e, stackTrace) {
      _logger.error('Failed to find storage URLs', e, stackTrace);
      rethrow;
    }
  }

  void _addIri(Triple triple, List<String> urls, RdfGraph graph) {
    switch (triple.object) {
      case IriTerm iriTerm:
        // If the storage points to an IRI, add it directly
        urls.add(iriTerm.iri);
        break;
      case BlankNodeTerm blankNodeTerm:
        // If the storage points to a blank node, look for location triples
        final locationTriples = graph.findTriples(
          subject: blankNodeTerm,
          predicate: IriTerm('http://www.w3.org/ns/solid/terms#location'),
        );
        for (final locationTriple in locationTriples) {
          _addIri(locationTriple, urls, graph);
        }
        break;
      case LiteralTerm _:
        _logger.warning(
          'Storage points to a literal, ignoring it: ${triple.object}',
        );
        // If the storage points to a literal, ignore it
        break;
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
        final graph = _rdfParserFactory
            .createParser(contentType: contentType)
            .parse(content, documentUrl: webId);

        final storageUrls = _findStorageUrls(graph);
        if (storageUrls.isNotEmpty) {
          _logger.info('Found storage URL: ${storageUrls.first}');
          return storageUrls.first;
        }

        // If no direct storage predicates were found, try other predicates
        for (final predicate in _storagePredicates) {
          final triples = graph.findTriples(predicate: predicate);
          if (triples.isNotEmpty) {
            final storageUrls = <String>[];
            for (final triple in triples) {
              _addIri(triple, storageUrls, graph);
            }
            final storageUrl = storageUrls[0];
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
