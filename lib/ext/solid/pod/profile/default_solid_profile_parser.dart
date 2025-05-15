import 'package:logging/logging.dart';

import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:solid_task/ext/solid/pod/profile/solid_profile_parser.dart';

final _log = Logger("solid.profile");

/// Implementation for parsing Solid profile documents
class DefaultSolidProfileParser implements SolidProfileParser {
  final RdfCore _rdfCore;

  static const solid = Namespace("http://www.w3.org/ns/solid/terms#");
  static const pim = Namespace("http://www.w3.org/ns/pim/space#");
  static const ldp = Namespace("http://www.w3.org/ns/ldp#");

  /// Common predicates used to identify storage locations in Solid profiles
  static final _storagePredicates = [
    pim('storage'),
    solid('storage'),
    ldp('contains'),
    solid('oidcIssuer'),
    solid('account'),
    solid('storageLocation'),
  ];

  /// Creates a new ProfileParser with the required dependencies
  DefaultSolidProfileParser({RdfCore? rdfCore})
    : _rdfCore = rdfCore ?? RdfCore.withStandardCodecs();

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
      _log.severe('Failed to find storage URLs', e, stackTrace);
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
        _log.warning(
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
    String? contentType,
  ) async {
    try {
      _log.info('Parsing profile with content type: $contentType');

      // Use the unified RdfParser to handle both Turtle and JSON-LD
      try {
        final graph = _rdfCore.decode(
          content,
          contentType: contentType,
          documentUrl: webId,
        );

        final storageUrls = _findStorageUrls(graph);
        if (storageUrls.isNotEmpty) {
          _log.info('Found storage URL: ${storageUrls.first}');
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
            _log.info(
              'Found storage URL with alternative predicate: $storageUrl',
            );
            return storageUrl;
          }
        }

        _log.warning('No storage URL found in profile document');
        return null;
      } catch (e, stackTrace) {
        _log.severe('RDF parsing failed', e, stackTrace);
        return null;
      }
    } catch (e, stackTrace) {
      _log.severe('Failed to parse profile', e, stackTrace);
      return null;
    }
  }
}
