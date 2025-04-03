// lib/services/profile_parser.dart

import 'dart:convert';
import 'logger_service.dart';

/// Service for parsing Solid profile documents to extract pod storage URLs.
class ProfileParser {
  static final _logger = LoggerService();

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

  /// Parse a profile document to extract the pod storage URL
  ///
  /// [webId] The WebID URL of the profile
  /// [content] The profile document content
  /// [contentType] The content type of the document
  static Future<String?> parseProfile(
    String webId,
    String content,
    String contentType,
  ) async {
    try {
      if (contentType.contains('text/turtle')) {
        _logger.info('Attempting to parse Turtle profile for WebID: $webId');
        final result = _parseTurtle(content, webId);
        if (result == null) {
          _logger.warning('No storage URL found in Turtle profile');
        }
        return result;
      } else if (contentType.contains('application/ld+json')) {
        _logger.info('Attempting to parse JSON-LD profile for WebID: $webId');
        final result = _parseJsonLd(content);
        if (result == null) {
          _logger.warning('No storage URL found in JSON-LD profile');
        }
        return result;
      } else {
        _logger.info('Unknown content type: $contentType, trying both formats');
        final turtleResult = _parseTurtle(content, webId);
        if (turtleResult != null) {
          _logger.info('Found storage URL in Turtle format');
          return turtleResult;
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
      _logger.error('Error parsing profile', e, stackTrace);
      return null;
    }
  }

  /// Parse a Turtle format profile document
  static String? _parseTurtle(String turtle, String webId) {
    try {
      _logger.debug('Starting Turtle parsing for WebID: $webId');

      // First, handle prefix definitions
      final prefixMap = _extractPrefixes(turtle);
      _logger.debug('Found ${prefixMap.length} prefix definitions');

      // Clean the WebID for matching
      final cleanWebId = webId.split('#')[0];
      _logger.debug('Using clean WebID: $cleanWebId');

      // Look for storage predicates using different syntax patterns
      for (final predicate in _storagePredicates) {
        _logger.debug('Trying predicate: $predicate');

        // Try with full URIs
        String? storage = _findStorageWithPattern(
          turtle,
          '<$cleanWebId>',
          '<$predicate>',
        );
        if (storage != null) {
          _logger.info('Found storage URL with full URI predicate: $storage');
          return storage;
        }

        // Try with prefixed notation
        for (final prefix in prefixMap.entries) {
          if (predicate.startsWith(prefix.value)) {
            final shortPredicate = predicate.replaceFirst(
              prefix.value,
              '${prefix.key}:',
            );
            _logger.debug('Trying prefixed predicate: $shortPredicate');
            storage = _findStorageWithPattern(
              turtle,
              '<$cleanWebId>',
              shortPredicate,
            );
            if (storage != null) {
              _logger.info(
                'Found storage URL with prefixed predicate: $storage',
              );
              return storage;
            }
          }
        }
      }

      // Try finding storage in type declarations
      _logger.debug('Checking for StorageContainer type declarations');
      for (final line in turtle.split('\n')) {
        if (line.contains('a') && line.contains('solid:StorageContainer')) {
          final uri = _extractUri(line);
          if (uri != null) {
            _logger.info('Found storage URL in type declaration: $uri');
            return uri;
          }
        }
      }

      _logger.warning('No storage URL found in Turtle document');
    } catch (e, stackTrace) {
      _logger.error('Error parsing Turtle', e, stackTrace);
    }
    return null;
  }

  /// Extract prefix definitions from a Turtle document
  static Map<String, String> _extractPrefixes(String turtle) {
    final prefixes = Map<String, String>.from(_commonPrefixes);

    // Look for @prefix declarations
    final prefixRegex = RegExp(
      r'@prefix\s+(\w+):\s*<([^>]+)>\s*\.',
      multiLine: true,
    );

    for (final match in prefixRegex.allMatches(turtle)) {
      if (match.groupCount == 2) {
        prefixes[match.group(1)!] = match.group(2)!;
      }
    }

    return prefixes;
  }

  /// Find storage URL using a specific pattern in Turtle syntax
  static String? _findStorageWithPattern(
    String turtle,
    String subject,
    String predicate,
  ) {
    // Pattern for quoted literals
    final regexQuoted = RegExp(
      '$subject\\s*$predicate\\s*"([^"]+)"\\s*\\.',
      caseSensitive: false,
    );

    // Pattern for URI references
    final regexAngled = RegExp(
      '$subject\\s*$predicate\\s*<([^>]+)>\\s*\\.',
      caseSensitive: false,
    );

    // Try quoted literal pattern
    final matchQuoted = regexQuoted.firstMatch(turtle);
    if (matchQuoted != null) {
      return matchQuoted.group(1);
    }

    // Try URI reference pattern
    final matchAngled = regexAngled.firstMatch(turtle);
    if (matchAngled != null) {
      return matchAngled.group(1);
    }

    return null;
  }

  /// Extract a URI from a line of Turtle
  static String? _extractUri(String line) {
    final uriRegex = RegExp(r'<([^>]+)>');
    final match = uriRegex.firstMatch(line);
    return match?.group(1);
  }

  /// Parse a JSON-LD format profile document
  static String? _parseJsonLd(String jsonLd) {
    try {
      _logger.debug('Starting JSON-LD parsing');
      final data = json.decode(jsonLd) as Map<String, dynamic>;

      // Try different JSON-LD structures
      if (data is Map<String, dynamic>) {
        _logger.debug('Checking direct storage properties');
        // Try direct storage property
        for (final predicate in _storagePredicates) {
          _logger.debug('Trying predicate: $predicate');
          final storage = _findStorageInObject(data, predicate);
          if (storage != null) {
            _logger.info('Found storage URL with direct predicate: $storage');
            return storage;
          }
        }

        // Try @graph structure
        if (data.containsKey('@graph')) {
          _logger.debug('Checking @graph structure');
          final graph = data['@graph'] as List<dynamic>;
          if (graph is List<dynamic>) {
            for (final node in graph) {
              if (node is Map<String, dynamic>) {
                _logger.debug('Checking node: ${node['@id']}');
                // Try each predicate in the node
                for (final predicate in _storagePredicates) {
                  final storage = _findStorageInObject(node, predicate);
                  if (storage != null) {
                    _logger.info('Found storage URL in @graph node: $storage');
                    return storage;
                  }
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
        }

        _logger.debug('Checking compact IRIs');
        // Try compact IRIs
        for (final entry in data.entries) {
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
      }

      _logger.warning('No storage URL found in JSON-LD document');
    } catch (e, stackTrace) {
      _logger.error('Error parsing JSON-LD', e, stackTrace);
    }
    return null;
  }

  /// Find storage URL in a JSON-LD object
  static String? _findStorageInObject(
    Map<String, dynamic> obj,
    String predicate,
  ) {
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
