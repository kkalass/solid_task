import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/rdf_constants.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:solid_task/services/rdf/rdf_type_converter.dart';
import 'package:solid_task/services/rdf/task_ontology_constants.dart';

/// Maps between Item domain objects and RDF triples
///
/// This class is responsible for converting Item domain objects to RDF
/// and vice versa, handling the mapping between domain model attributes
/// and their RDF representation.
class ItemRdfMapper {
  final ContextLogger _logger;
  final RdfTypeConverter _typeConverter;

  /// Creates a new ItemRdfMapper
  ///
  /// [loggerService] Optional logger for diagnostic information
  /// [typeConverter] Converter for RDF data types (will be created if not provided)
  ItemRdfMapper({LoggerService? loggerService, RdfTypeConverter? typeConverter})
    : _logger = (loggerService ?? LoggerService()).createLogger(
        'ItemRdfMapper',
      ),
      _typeConverter =
          typeConverter ?? RdfTypeConverter(loggerService: loggerService);

  /// Common RDF prefixes for task serialization
  Map<String, String> get commonPrefixes => {
    'rdf': RdfConstants.namespace,
    'dcterms': DcTermsConstants.namespace,
    'xsd': XsdConstants.namespace,
    'task': TaskOntologyConstants.namespace,
  };

  /// Maps an Item to an RDF graph and returns the graph and prefixes
  (RdfGraph, Map<String, String>) mapItemToRdf(Item item) {
    _logger.debug('Mapping item ${item.id} to RDF');

    final triples = <Triple>[];
    final itemUri = TaskOntologyConstants.makeTaskUri(item.id);
    final itemIri = IriTerm(itemUri);

    // Add triple: <itemUri> rdf:type task:Task
    triples.add(
      Triple(itemIri, RdfConstants.typeIri, TaskOntologyConstants.taskClassIri),
    );

    // Add item properties
    triples.add(
      Triple(
        itemIri,
        TaskOntologyConstants.textIri,
        _typeConverter.createStringLiteral(item.text),
      ),
    );

    triples.add(
      Triple(
        itemIri,
        TaskOntologyConstants.isDeletedIri,
        _typeConverter.createBooleanLiteral(item.isDeleted),
      ),
    );

    triples.add(
      Triple(
        itemIri,
        DcTermsConstants.createdIri,
        _typeConverter.createDateTimeLiteral(item.createdAt),
      ),
    );

    triples.add(
      Triple(
        itemIri,
        DcTermsConstants.creatorIri,
        _typeConverter.createStringLiteral(item.lastModifiedBy),
      ),
    );

    // Handle vector clock
    for (final entry in item.vectorClock.entries) {
      final clockEntryUri = TaskOntologyConstants.makeVectorClockEntryUri(
        item.id,
        entry.key,
      );
      final clockEntryIri = IriTerm(clockEntryUri);

      // Add the vector clock entry node
      triples.add(
        Triple(itemIri, TaskOntologyConstants.vectorClockIri, clockEntryIri),
      );

      triples.add(
        Triple(
          clockEntryIri,
          RdfConstants.typeIri,
          TaskOntologyConstants.vectorClockEntryIri,
        ),
      );

      triples.add(
        Triple(
          clockEntryIri,
          TaskOntologyConstants.clientIdIri,
          _typeConverter.createStringLiteral(entry.key),
        ),
      );

      triples.add(
        Triple(
          clockEntryIri,
          TaskOntologyConstants.clockValueIri,
          _typeConverter.createIntegerLiteral(entry.value),
        ),
      );
    }

    final graph = RdfGraph(triples: triples);
    return (graph, commonPrefixes);
  }

  /// Maps an RDF graph to an Item
  ///
  /// [graph] The RDF graph containing the item data
  /// [itemUri] The URI of the item in the graph
  ///
  /// Throws FormatException if required properties are missing or have invalid types
  Item mapRdfToItem(RdfGraph graph, String itemUri) {
    _logger.debug('Mapping RDF to Item for URI: $itemUri');
    final subjectIri = IriTerm(itemUri);

    // Extract text property (required)
    final text = _extractRequiredStringProperty(
      graph,
      subjectIri,
      TaskOntologyConstants.textIri,
      'text',
    );

    // Extract creator property (required)
    final modifiedBy = _extractRequiredStringProperty(
      graph,
      subjectIri,
      DcTermsConstants.creatorIri,
      'creator',
    );

    // Create the base item
    final item = Item(text: text, lastModifiedBy: modifiedBy);

    // Extract ID from URI
    item.id = itemUri.split('/').last;

    // Extract optional creation time
    _extractOptionalDateTimeProperty(
      graph,
      subjectIri,
      DcTermsConstants.createdIri,
      (value) => item.createdAt = value,
    );

    // Extract optional deleted flag
    _extractOptionalBooleanProperty(
      graph,
      subjectIri,
      TaskOntologyConstants.isDeletedIri,
      (value) => item.isDeleted = value,
    );

    // Extract vector clock
    final vectorClock = _extractVectorClock(graph, subjectIri);
    if (vectorClock.isNotEmpty) {
      item.vectorClock = vectorClock;
    }

    return item;
  }

  // Helper methods for property extraction

  String _extractRequiredStringProperty(
    RdfGraph graph,
    IriTerm subject,
    IriTerm predicate,
    String propertyName,
  ) {
    final triples = graph.findTriples(subject: subject, predicate: predicate);

    if (triples.isEmpty) {
      throw FormatException(
        'Missing required $propertyName property for item: ${subject.iri}',
      );
    }

    final literal = triples.first.object;
    if (literal is! LiteralTerm) {
      throw FormatException(
        '$propertyName property is not a literal: $literal',
      );
    }

    return literal.value;
  }

  void _extractOptionalDateTimeProperty(
    RdfGraph graph,
    IriTerm subject,
    IriTerm predicate,
    void Function(DateTime) setter,
  ) {
    final triples = graph.findTriples(subject: subject, predicate: predicate);

    if (triples.isNotEmpty) {
      final literal = triples.first.object;
      if (literal is LiteralTerm) {
        final dateTime = _typeConverter.parseDateTime(literal);
        if (dateTime != null) {
          setter(dateTime);
        }
      }
    }
  }

  void _extractOptionalBooleanProperty(
    RdfGraph graph,
    IriTerm subject,
    IriTerm predicate,
    void Function(bool) setter,
  ) {
    final triples = graph.findTriples(subject: subject, predicate: predicate);

    if (triples.isNotEmpty) {
      final literal = triples.first.object;
      if (literal is LiteralTerm) {
        final value = _typeConverter.parseBoolean(literal);
        if (value != null) {
          setter(value);
        }
      }
    }
  }

  Map<String, int> _extractVectorClock(RdfGraph graph, IriTerm subjectIri) {
    final vectorClockTriples = graph.findTriples(
      subject: subjectIri,
      predicate: TaskOntologyConstants.vectorClockIri,
    );

    final vectorClock = <String, int>{};

    for (final triple in vectorClockTriples) {
      final entryIri = triple.object;
      if (entryIri is! IriTerm) continue;

      final clientIdTriples = graph.findTriples(
        subject: entryIri,
        predicate: TaskOntologyConstants.clientIdIri,
      );

      final valueTriples = graph.findTriples(
        subject: entryIri,
        predicate: TaskOntologyConstants.clockValueIri,
      );

      if (clientIdTriples.isNotEmpty && valueTriples.isNotEmpty) {
        final clientIdObj = clientIdTriples.first.object;
        final valueObj = valueTriples.first.object;

        if (clientIdObj is LiteralTerm && valueObj is LiteralTerm) {
          final clientId = clientIdObj.value;
          final value = _typeConverter.parseInteger(valueObj) ?? 0;
          vectorClock[clientId] = value;
        }
      }
    }

    return vectorClock;
  }
}
