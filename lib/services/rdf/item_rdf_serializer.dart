// filepath: /Users/klaskalass/privat/solid_task/lib/services/rdf/item_rdf_serializer.dart
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:solid_task/services/rdf/rdf_parser.dart';
import 'package:solid_task/services/rdf/rdf_serializer.dart';

/// Service for converting Items to RDF and vice versa
class ItemRdfSerializer {
  final ContextLogger _logger;
  final RdfSerializer _serializer;
  final RdfParser _parser;

  // Standard RDF vocabularies
  static const String _rdfType =
      'http://www.w3.org/1999/02/22-rdf-syntax-ns#type';
  static const String _dcTerms = 'http://purl.org/dc/terms/';

  // Application-specific vocabulary
  static const String _taskOntology = 'http://solidtask.org/ontology#';
  static const String _taskClass = '${_taskOntology}Task';

  // Properties
  static const String _taskText = '${_taskOntology}text';
  static const String _taskIsDeleted = '${_taskOntology}isDeleted';
  static const String _taskCreated = '${_dcTerms}created';
  static const String _taskModifiedBy = '${_dcTerms}creator';
  static const String _taskVectorClock = '${_taskOntology}vectorClock';
  static const String _taskVectorClockEntry =
      '${_taskOntology}vectorClockEntry';
  static const String _taskClientId = '${_taskOntology}clientId';
  static const String _taskClockValue = '${_taskOntology}clockValue';

  /// Creates a new ItemRdfSerializer for converting Items to/from RDF.
  ///
  /// Uses the factory pattern to create appropriate RDF serializer and parser implementations.
  ///
  /// Parameters:
  /// - [loggerService]: Optional logger for diagnostic information
  /// - [contentType]: MIME type for serialization format (defaults to 'text/turtle')
  /// - [serializerFactory]: Factory for creating RDF serializers (useful for testing with custom serializers)
  /// - [parserFactory]: Factory for creating RDF parsers (useful for testing with custom parsers)
  ItemRdfSerializer({
    LoggerService? loggerService,
    String? contentType = 'text/turtle',
    RdfSerializerFactory? serializerFactory,
    RdfParserFactory? parserFactory,
  }) : _logger = (loggerService ?? LoggerService()).createLogger(
         'ItemRdfSerializer',
       ),
       _serializer = (serializerFactory ??
               RdfSerializerFactory(loggerService: loggerService))
           .createSerializer(contentType: contentType),
       _parser = (parserFactory ??
               RdfParserFactory(loggerService: loggerService))
           .createParser(contentType: contentType);

  /// Converts an Item to an RDF graph
  (RdfGraph, Map<String, String>) itemToRdf(Item item) {
    _logger.debug('Converting item ${item.id} to RDF');

    final triples = <Triple>[];

    // Add common prefixes
    final prefixes = {
      'rdf': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
      'dcterms': 'http://purl.org/dc/terms/',
      'xsd': 'http://www.w3.org/2001/XMLSchema#',
      'task': 'http://solidtask.org/ontology#',
    };

    // Base item URI
    final itemUri = 'http://solidtask.org/tasks/${item.id}';
    final itemIri = IriTerm(itemUri);

    // Add triple: <itemUri> rdf:type task:Task
    triples.add(Triple(itemIri, IriTerm(_rdfType), IriTerm(_taskClass)));

    // Add item properties
    triples.add(
      Triple(itemIri, IriTerm(_taskText), _createStringLiteral(item.text)),
    );

    triples.add(
      Triple(
        itemIri,
        IriTerm(_taskIsDeleted),
        _createBooleanLiteral(item.isDeleted),
      ),
    );

    triples.add(
      Triple(
        itemIri,
        IriTerm(_taskCreated),
        _createDateTimeLiteral(item.createdAt),
      ),
    );

    triples.add(
      Triple(
        itemIri,
        IriTerm(_taskModifiedBy),
        _createStringLiteral(item.lastModifiedBy),
      ),
    );

    // Handle vector clock
    for (final entry in item.vectorClock.entries) {
      final clockEntryUri = '$itemUri/vectorClock/${entry.key}';
      final clockEntryIri = IriTerm(clockEntryUri);

      // Add the vector clock entry node
      triples.add(Triple(itemIri, IriTerm(_taskVectorClock), clockEntryIri));

      triples.add(
        Triple(
          clockEntryIri,
          IriTerm(_rdfType),
          IriTerm(_taskVectorClockEntry),
        ),
      );

      triples.add(
        Triple(
          clockEntryIri,
          IriTerm(_taskClientId),
          _createStringLiteral(entry.key),
        ),
      );

      triples.add(
        Triple(
          clockEntryIri,
          IriTerm(_taskClockValue),
          _createIntegerLiteral(entry.value),
        ),
      );
    }
    final graph = RdfGraph(triples: triples);
    return (graph, prefixes);
  }

  /// Extracts an Item from an RDF graph
  Item rdfToItem(RdfGraph graph, String itemUri) {
    _logger.debug('Converting RDF back to Item for URI: $itemUri');
    final subjectIri = IriTerm(itemUri);

    // Extract basic properties
    final textTriples = graph.findTriples(
      subject: subjectIri,
      predicate: IriTerm(_taskText),
    );

    if (textTriples.isEmpty) {
      throw FormatException(
        'Missing required text property for item: $itemUri',
      );
    }

    final textLiteral = textTriples.first.object;
    if (textLiteral is! LiteralTerm) {
      throw FormatException('Text property is not a literal: $textLiteral');
    }
    final text = textLiteral.value;

    final modifiedByTriples = graph.findTriples(
      subject: subjectIri,
      predicate: IriTerm(_taskModifiedBy),
    );

    if (modifiedByTriples.isEmpty) {
      throw FormatException(
        'Missing required creator property for item: $itemUri',
      );
    }

    final modifiedByLiteral = modifiedByTriples.first.object;
    if (modifiedByLiteral is! LiteralTerm) {
      throw FormatException(
        'Creator property is not a literal: $modifiedByLiteral',
      );
    }
    final modifiedBy = modifiedByLiteral.value;

    // Create the base item
    final item = Item(text: text, lastModifiedBy: modifiedBy);

    // Extract ID from URI
    item.id = itemUri.split('/').last;

    // Extract creation time
    final createdTriples = graph.findTriples(
      subject: subjectIri,
      predicate: IriTerm(_taskCreated),
    );

    if (createdTriples.isNotEmpty) {
      final createdLiteral = createdTriples.first.object;
      if (createdLiteral is LiteralTerm) {
        try {
          item.createdAt = DateTime.parse(createdLiteral.value).toUtc();
        } catch (e) {
          _logger.warning(
            'Failed to parse date: ${createdLiteral.value}. Error: $e',
          );
        }
      }
    }

    // Extract deleted flag
    final deletedTriples = graph.findTriples(
      subject: subjectIri,
      predicate: IriTerm(_taskIsDeleted),
    );

    if (deletedTriples.isNotEmpty) {
      final deletedLiteral = deletedTriples.first.object;
      if (deletedLiteral is LiteralTerm) {
        item.isDeleted = deletedLiteral.value.toLowerCase() == 'true';
      }
    }

    // Extract vector clock
    final vectorClockTriples = graph.findTriples(
      subject: subjectIri,
      predicate: IriTerm(_taskVectorClock),
    );
    final vectorClock = <String, int>{};

    for (final triple in vectorClockTriples) {
      final entryIri = triple.object;
      if (entryIri is! IriTerm) continue;

      final clientIdTriples = graph.findTriples(
        subject: entryIri,
        predicate: IriTerm(_taskClientId),
      );

      final valueTriples = graph.findTriples(
        subject: entryIri,
        predicate: IriTerm(_taskClockValue),
      );

      if (clientIdTriples.isNotEmpty && valueTriples.isNotEmpty) {
        final clientIdObj = clientIdTriples.first.object;
        final valueObj = valueTriples.first.object;

        if (clientIdObj is LiteralTerm && valueObj is LiteralTerm) {
          final clientId = clientIdObj.value;
          final value = int.tryParse(valueObj.value) ?? 0;
          vectorClock[clientId] = value;
        }
      }
    }

    // Only replace if we found vector clock entries
    if (vectorClock.isNotEmpty) {
      item.vectorClock = vectorClock;
    }

    return item;
  }

  /// Serializes an Item to a string representation in the configured format
  String itemToString(Item item) {
    final (graph, prefixes) = itemToRdf(item);
    return _serializer.write(graph, prefixes: prefixes);
  }

  /// Parses an Item from a string representation in the specified format
  Item itemFromString(String content, String itemId, {String? documentUrl}) {
    final graph = _parser.parse(content, documentUrl: documentUrl);

    final itemUri = 'http://solidtask.org/tasks/$itemId';
    return rdfToItem(graph, itemUri);
  }

  // Helper methods for creating typed literals

  /// Creates a string literal term
  LiteralTerm _createStringLiteral(String value) {
    return LiteralTerm.string(value);
  }

  /// Creates a boolean literal with XSD boolean datatype
  LiteralTerm _createBooleanLiteral(bool value) {
    return LiteralTerm.typed(value.toString(), 'boolean');
  }

  /// Creates a dateTime literal with XSD dateTime datatype
  LiteralTerm _createDateTimeLiteral(DateTime dateTime) {
    final utcDateTime = dateTime.toUtc();
    final isoString = utcDateTime.toIso8601String();
    return LiteralTerm.typed(isoString, 'dateTime');
  }

  /// Creates an integer literal with XSD integer datatype
  LiteralTerm _createIntegerLiteral(int value) {
    return LiteralTerm.typed(value.toString(), 'integer');
  }
}
