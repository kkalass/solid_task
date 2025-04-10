// lib/services/profile_parser.dart

import 'dart:convert';
import 'package:solid_task/services/logger_service.dart';
import 'turtle_parser/turtle_parser.dart';

/// Interface for profile parsing operations
abstract class ProfileParserService {
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
class DefaultProfileParser implements ProfileParserService {
  final ContextLogger _logger;
  final TurtleParserFacade _turtleParser;

  /// Common predicates used to identify storage locations in Solid profiles
  static const _storagePredicates = [
    'http://www.w3.org/ns/pim/space#storage',
    'http://www.w3.org/ns/solid/terms#storage',
    'http://www.w3.org/ns/ldp#contains',
    'http://www.w3.org/ns/solid/terms#oidcIssuer',
    'http://www.w3.org/ns/solid/terms#account',
    'http://www.w3.org/ns/solid/terms#storageLocation',
  ];

  /// Common prefixes used in Turtle documents
  static const _commonPrefixes = {
    'solid': 'http://www.w3.org/ns/solid/terms#',
    'space': 'http://www.w3.org/ns/pim/space#',
    'ldp': 'http://www.w3.org/ns/ldp#',
    'pim': 'http://www.w3.org/ns/pim/space#',
  };

  /// Creates a new ProfileParser with the required dependencies
  DefaultProfileParser({
    LoggerService? loggerService,
    TurtleParserFacade? turtleParser,
  }) : _logger = (loggerService ?? LoggerService()).createLogger(
         'DefaultProfileParser',
       ),
       _turtleParser =
           turtleParser ?? DefaultTurtleParser(loggerService: loggerService);

  @override
  Future<String?> parseStorageUrl(
    String webId,
    String content,
    String contentType,
  ) async {
    try {
      _logger.info('Parsing profile with content type: $contentType');

      if (contentType.contains('text/turtle')) {
        final storageUrls = _turtleParser.findStorageUrls(
          content,
          documentUrl: webId,
        );
        return storageUrls.isNotEmpty ? storageUrls.first : null;
      } else if (contentType.contains('application/ld+json')) {
        return _parseJsonLd(content);
      } else {
        _logger.info('Unknown content type: $contentType, trying both formats');
        List<String> turtleUrls = [];
        try {
          turtleUrls = _turtleParser.findStorageUrls(
            content,
            documentUrl: webId,
          );
        } catch (e, stackTrace) {
          _logger.debug(
            'Failed to parse as Turtle, trying JSON-LD',
            e,
            stackTrace,
          );
        }
        if (turtleUrls.isNotEmpty) {
          _logger.info('Found storage URL in Turtle format');
          return turtleUrls.first;
        }
        final jsonLdResult = _parseJsonLd(content);
        if (jsonLdResult != null) {
          _logger.info('Found storage URL in JSON-LD format');
          return jsonLdResult;
        }
        _logger.warning('No storage URL found in either format');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to parse profile', e, stackTrace);
      return null;
    }
  }

  // FIXME KK - we should refactor the turtle_parser into a more proper rdf library with both turtle and json-ld parsers and writers, working on the same graph
  /// Parse a JSON-LD format profile document
  String? _parseJsonLd(String jsonLd) {
    try {
      _logger.debug('Starting JSON-LD parsing');
      final decoded = json.decode(jsonLd);

      // Handle array at root level
      if (decoded is List) {
        _logger.debug('Found array at root level');
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _logger.debug('Checking array item: ${item['@id']}');
            final result = _parseJsonLdObject(item);
            if (result != null) return result;
          }
        }
      }

      // Handle object at root level
      if (decoded is Map<String, dynamic>) {
        return _parseJsonLdObject(decoded);
      }

      _logger.warning('No storage URL found in JSON-LD document');
    } catch (e, stackTrace) {
      _logger.error('Error parsing JSON-LD', e, stackTrace);
    }
    return null;
  }

  /// Parse a JSON-LD object to find storage URL
  String? _parseJsonLdObject(Map<String, dynamic> obj) {
    _logger.debug('Checking direct storage properties');
    // Try direct storage property
    final directResult = _findStorageInObjectWithPredicates(obj);
    if (directResult != null) {
      _logger.info('Found storage URL with direct predicate: $directResult');
      return directResult;
    }

    // Try @graph structure
    if (obj.containsKey('@graph')) {
      _logger.debug('Checking @graph structure');
      final graph = obj['@graph'] as List<dynamic>;
      for (final node in graph) {
        if (node is Map<String, dynamic>) {
          _logger.debug('Checking node: ${node['@id']}');
          final result = _findStorageInObjectWithPredicates(node);
          if (result != null) {
            _logger.info('Found storage URL in @graph node: $result');
            return result;
          }

          // Try type-based detection
          if (node['@type'] == 'solid:StorageContainer' ||
              node['@type'] == 'pim:Storage') {
            final id = node['@id'];
            if (id is String) {
              _logger.info('Found storage URL in type declaration: $id');
              return id;
            }
          }
        }
      }
    }

    _logger.debug('Checking compact IRIs');
    // Try compact IRIs
    for (final entry in obj.entries) {
      if (entry.key.startsWith('solid:') ||
          entry.key.startsWith('space:') ||
          entry.key.startsWith('pim:')) {
        _logger.debug('Found compact IRI: ${entry.key}');
        final value = entry.value;
        if (value is String) {
          _logger.info('Found storage URL in compact IRI: $value');
          return value;
        }
        if (value is Map && value.containsKey('@id')) {
          final id = value['@id'];
          _logger.info('Found storage URL in compact IRI object: $id');
          return id;
        }
      }
    }

    return null;
  }

  /// Find storage URL in a JSON-LD object using all storage predicates
  String? _findStorageInObjectWithPredicates(Map<String, dynamic> obj) {
    for (final predicate in _storagePredicates) {
      _logger.debug('Trying predicate: $predicate');
      final storage = _findStorageInObject(obj, predicate);
      if (storage != null) return storage;
    }
    return null;
  }

  /// Find storage URL in a JSON-LD object
  String? _findStorageInObject(Map<String, dynamic> obj, String predicate) {
    // Try direct predicate
    final value = obj[predicate];
    if (value != null) {
      if (value is String) return value;
      if (value is Map && value.containsKey('@id')) return value['@id'];
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is String) return first;
        if (first is Map && first.containsKey('@id')) return first['@id'];
      }
    }

    // Try with compact IRI
    for (final prefix in _commonPrefixes.entries) {
      if (predicate.startsWith(prefix.value)) {
        final shortPredicate = predicate.replaceFirst(
          prefix.value,
          '${prefix.key}:',
        );
        final value = obj[shortPredicate];
        if (value != null) {
          if (value is String) return value;
          if (value is Map && value.containsKey('@id')) return value['@id'];
        }
      }
    }

    return null;
  }
}
