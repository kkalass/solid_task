// lib/services/rdf/jsonld/jsonld_parser.dart

import 'dart:convert';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';

/// A parser for JSON-LD (JSON for Linked Data) format.
///
/// JSON-LD is a lightweight Linked Data format based on JSON. It provides a way
/// to help JSON data interoperate at Web-scale by adding semantic context to JSON data.
/// This parser supports:
///
/// - Basic JSON-LD document parsing
/// - Subject-predicate-object triple extraction
/// - Context resolution for compact IRIs
/// - Graph structure parsing (@graph)
/// - Type coercion
///
/// Example usage:
/// ```dart
/// final parser = JsonLdParser('''
///   {
///     "@context": {
///       "name": "http://xmlns.com/foaf/0.1/name"
///     },
///     "@id": "http://example.com/me",
///     "name": "John Doe"
///   }
/// ''', baseUri: 'http://example.com/');
/// final triples = parser.parse();
/// ```
class JsonLdParser {
  final ContextLogger _logger;
  final String _input;
  final String? _baseUri;

  // Common prefixes used in JSON-LD documents
  static const Map<String, String> _commonPrefixes = {
    'rdf': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    'rdfs': 'http://www.w3.org/2000/01/rdf-schema#',
    'xsd': 'http://www.w3.org/2001/XMLSchema#',
    'owl': 'http://www.w3.org/2002/07/owl#',
    'solid': 'http://www.w3.org/ns/solid/terms#',
    'space': 'http://www.w3.org/ns/pim/space#',
    'ldp': 'http://www.w3.org/ns/ldp#',
    'pim': 'http://www.w3.org/ns/pim/space#',
    'foaf': 'http://xmlns.com/foaf/0.1/',
    'schema': 'http://schema.org/',
    'dc': 'http://purl.org/dc/terms/',
  };

  /// Creates a new JSON-LD parser for the given input string.
  ///
  /// [input] is the JSON-LD document to parse.
  /// [baseUri] is the base URI against which relative IRIs should be resolved.
  /// If not provided, relative IRIs will be kept as-is.
  JsonLdParser(String input, {String? baseUri, LoggerService? loggerService})
    : _input = input,
      _baseUri = baseUri,
      _logger = (loggerService ?? LoggerService()).createLogger('JsonLdParser');

  /// Parses the JSON-LD input and returns a list of triples.
  ///
  /// This method processes the input by:
  /// 1. Parsing the JSON document
  /// 2. Extracting the @context if present
  /// 3. Processing the document structure to generate RDF triples
  ///
  /// Throws [FormatException] if the input is not valid JSON-LD.
  List<Triple> parse() {
    try {
      _logger.debug('Starting JSON-LD parsing');
      final dynamic jsonData = json.decode(_input);
      final triples = <Triple>[];

      if (jsonData is List) {
        _logger.debug('Parsing JSON-LD array');
        // Handle JSON-LD array
        for (final item in jsonData) {
          if (item is Map<String, dynamic>) {
            triples.addAll(_processNode(item));
          } else {
            _logger.warning('Skipping non-object item in JSON-LD array');
          }
        }
      } else if (jsonData is Map<String, dynamic>) {
        _logger.debug('Parsing JSON-LD object');
        // Handle JSON-LD object
        triples.addAll(_processNode(jsonData));
      } else {
        _logger.error('JSON-LD must be an object or array at the top level');
        throw FormatException('Invalid JSON-LD: must be an object or array');
      }

      _logger.debug(
        'JSON-LD parsing complete. Found ${triples.length} triples',
      );
      return triples;
    } catch (e, stack) {
      _logger.error('Failed to parse JSON-LD', e, stack);
      if (e is FormatException) {
        rethrow;
      }
      throw FormatException('Invalid JSON-LD: ${e.toString()}');
    }
  }

  /// Process a JSON-LD node and extract triples
  List<Triple> _processNode(Map<String, dynamic> node) {
    final triples = <Triple>[];
    final context = _extractContext(node);

    // Handle @graph property if present
    if (node.containsKey('@graph')) {
      _logger.debug('Processing @graph structure');
      final graph = node['@graph'];

      if (graph is List) {
        for (final item in graph) {
          if (item is Map<String, dynamic>) {
            // Pass context to each graph item
            triples.addAll(_extractTriples(item, context));
          }
        }
      }
      return triples;
    }

    // Process regular node
    triples.addAll(_extractTriples(node, context));

    return triples;
  }

  /// Extract context from JSON-LD node
  Map<String, String> _extractContext(Map<String, dynamic> node) {
    final context = <String, String>{};

    // Add common prefixes as default context
    context.addAll(_commonPrefixes);

    // Extract @context if present
    if (node.containsKey('@context')) {
      final nodeContext = node['@context'];

      if (nodeContext is Map<String, dynamic>) {
        for (final entry in nodeContext.entries) {
          if (entry.value is String) {
            context[entry.key] = entry.value as String;
            _logger.debug(
              'Found context mapping: ${entry.key} -> ${entry.value}',
            );
          } else if (entry.value is Map<String, dynamic>) {
            // Handle complex context definitions
            final valueMap = entry.value as Map<String, dynamic>;
            if (valueMap.containsKey('@id')) {
              context[entry.key] = valueMap['@id'] as String;
              _logger.debug(
                'Found complex context mapping: ${entry.key} -> ${valueMap['@id']}',
              );
            }
          }
        }
      }
    }

    return context;
  }

  /// Extract triples from a JSON-LD node
  List<Triple> _extractTriples(
    Map<String, dynamic> node,
    Map<String, String> context,
  ) {
    final triples = <Triple>[];

    // Determine the subject
    final String subject = _getSubjectId(node);
    _logger.debug('Processing node with subject: $subject');

    // Process all properties except @context and @id
    for (final entry in node.entries) {
      final key = entry.key;
      final value = entry.value;

      // Skip JSON-LD keywords
      if (key.startsWith('@')) {
        if (key == '@type') {
          // Handle @type specially to generate rdf:type triples
          _processType(subject, value, triples, context);
        }
        continue;
      }

      // Expand predicate using context
      final predicate = _expandPredicate(key, context);
      _logger.debug('Processing property: $key -> $predicate');

      if (value is List) {
        // Handle array values
        for (final item in value) {
          _addTripleForValue(subject, predicate, item, triples, context);
        }
      } else {
        // Handle single value
        _addTripleForValue(subject, predicate, value, triples, context);
      }
    }

    return triples;
  }

  /// Get the subject identifier from a node
  String _getSubjectId(Map<String, dynamic> node) {
    if (node.containsKey('@id')) {
      final id = node['@id'] as String;

      // Resolve relative IRIs against the base URI if one is provided
      if (_baseUri != null && !id.contains('://') && !id.startsWith('_:')) {
        return Uri.parse(_baseUri).resolve(id).toString();
      }

      return id;
    }

    // Generate blank node identifier if no @id is present
    return '_:b${node.hashCode.abs()}';
  }

  /// Process @type value and add appropriate triples
  void _processType(
    String subject,
    dynamic typeValue,
    List<Triple> triples,
    Map<String, String> context,
  ) {
    final typeProperty = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type';

    if (typeValue is List) {
      for (final type in typeValue) {
        if (type is String) {
          final expandedType = _expandPredicate(type, context);
          triples.add(Triple(subject, typeProperty, expandedType));
          _logger.debug(
            'Added type triple: $subject -> $typeProperty -> $expandedType',
          );
        }
      }
    } else if (typeValue is String) {
      final expandedType = _expandPredicate(typeValue, context);
      triples.add(Triple(subject, typeProperty, expandedType));
      _logger.debug(
        'Added type triple: $subject -> $typeProperty -> $expandedType',
      );
    }
  }

  /// Add a triple for a given value
  void _addTripleForValue(
    String subject,
    String predicate,
    dynamic value,
    List<Triple> triples,
    Map<String, String> context,
  ) {
    if (value is String) {
      // Simple literal or IRI value
      if (value.startsWith('http://') || value.startsWith('https://')) {
        // Treat as IRI
        triples.add(Triple(subject, predicate, value));
        _logger.debug('Added IRI triple: $subject -> $predicate -> $value');
      } else {
        // Treat as literal
        triples.add(Triple(subject, predicate, '"$value"'));
        _logger.debug(
          'Added literal triple: $subject -> $predicate -> "$value"',
        );
      }
    } else if (value is num || value is bool) {
      // Numeric or boolean literal
      triples.add(Triple(subject, predicate, '"$value"'));
      _logger.debug('Added literal triple: $subject -> $predicate -> "$value"');
    } else if (value is Map<String, dynamic>) {
      // Object value (nested node or value with metadata)
      if (value.containsKey('@id')) {
        // Reference to another resource
        final objectId = value['@id'] as String;
        triples.add(Triple(subject, predicate, _expandIri(objectId)));
        _logger.debug(
          'Added object reference triple: $subject -> $predicate -> ${_expandIri(objectId)}',
        );

        // If the object has more properties, process it recursively
        if (value.keys.any((k) => !k.startsWith('@'))) {
          triples.addAll(_extractTriples(value, context));
        }
      } else if (value.containsKey('@value')) {
        // Typed or language-tagged literal
        final literalValue = value['@value'];
        String objectValue = '"$literalValue"';

        if (value.containsKey('@type')) {
          // Typed literal
          objectValue = '$objectValue^^${value['@type']}';
        } else if (value.containsKey('@language')) {
          // Language-tagged literal
          objectValue = '$objectValue@${value['@language']}';
        }

        triples.add(Triple(subject, predicate, objectValue));
        _logger.debug(
          'Added complex literal triple: $subject -> $predicate -> $objectValue',
        );
      } else {
        // Blank node
        final blankNodeId = '_:b${value.hashCode.abs()}';
        triples.add(Triple(subject, predicate, blankNodeId));
        _logger.debug(
          'Added blank node triple: $subject -> $predicate -> $blankNodeId',
        );

        // Process the blank node recursively
        value['@id'] = blankNodeId;
        triples.addAll(_extractTriples(value, context));
      }
    }
  }

  /// Expand a predicate using the context
  String _expandPredicate(String key, Map<String, String> context) {
    if (key.contains(':')) {
      // Handle prefixed name
      final parts = key.split(':');
      if (parts.length == 2 && context.containsKey(parts[0])) {
        return '${context[parts[0]]}${parts[1]}';
      }
    }

    // Direct match in context
    if (context.containsKey(key)) {
      return context[key]!;
    }

    // Full IRI or unknown property
    if (key.startsWith('http://') || key.startsWith('https://')) {
      return key;
    }

    // Return the key as-is if we can't resolve it
    _logger.warning('Unable to resolve predicate: $key');
    return key;
  }

  /// Expand an IRI using the base URI if needed
  String _expandIri(String iri) {
    if (iri.startsWith('http://') ||
        iri.startsWith('https://') ||
        iri.startsWith('_:')) {
      return iri;
    }

    // Try to resolve against base URI if available
    if (_baseUri != null) {
      try {
        return Uri.parse(_baseUri).resolve(iri).toString();
      } catch (e) {
        _logger.warning('Failed to resolve IRI against base URI: $iri', e);
      }
    }

    return iri;
  }
}
