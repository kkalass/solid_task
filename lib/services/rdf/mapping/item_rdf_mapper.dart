import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/mapping/rdf_mapper_registry.dart';
import 'package:solid_task/services/rdf/mapping/rdf_type_converter.dart';
import 'package:solid_task/services/rdf/rdf_constants.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:solid_task/services/rdf/task_ontology_constants.dart';

/// RDF mapper for Item domain objects
///
/// This class handles the conversion between Item domain objects and their
/// RDF representation, including vector clock entries for CRDT functionality.
final class ItemRdfMapper implements RdfTypeMapper<Item> {
  final ContextLogger _logger;
  final RdfTypeConverter _typeConverter;

  /// Creates a new ItemRdfMapper
  ///
  /// @param loggerService Optional logger for diagnostic information
  /// @param typeConverter Type converter for RDF literals (will be created if not provided)
  ItemRdfMapper({LoggerService? loggerService, RdfTypeConverter? typeConverter})
    : _logger = (loggerService ?? LoggerService()).createLogger(
        'ItemRdfMapper',
      ),
      _typeConverter =
          typeConverter ?? RdfTypeConverter(loggerService: loggerService);

  @override
  Item createInstance() {
    return Item(text: '', lastModifiedBy: '');
  }

  @override
  Item fromTriples(List<Triple> triples, String subjectUri) {
    _logger.debug('Converting triples to Item with subject: $subjectUri');

    final graph = RdfGraph(triples: triples);
    final subjectIri = IriTerm(subjectUri);

    // Extract required properties
    final text = _extractRequiredStringProperty(
      graph,
      subjectIri,
      TaskOntologyConstants.textIri,
      'text',
    );

    final lastModifiedBy = _extractRequiredStringProperty(
      graph,
      subjectIri,
      DcTermsConstants.creatorIri,
      'lastModifiedBy',
    );

    // Create base item
    final item = Item(text: text, lastModifiedBy: lastModifiedBy);

    // Extract ID from URI
    item.id = subjectUri.split('/').last;

    // Extract optional properties
    _extractOptionalDateTimeProperty(
      graph,
      subjectIri,
      DcTermsConstants.createdIri,
      (value) => item.createdAt = value,
    );

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

  @override
  String generateUri(Item instance, {String? baseUri}) {
    final base = baseUri ?? TaskOntologyConstants.taskBaseUri;
    return '$base${instance.id}';
  }

  @override
  List<Triple> toTriples(Item instance, String subjectUri) {
    _logger.debug('Converting Item ${instance.id} to triples');

    final triples = <Triple>[];
    final itemIri = IriTerm(subjectUri);

    // Add rdf:type
    triples.add(
      Triple(itemIri, RdfConstants.typeIri, TaskOntologyConstants.taskClassIri),
    );

    // Add basic properties
    triples.add(
      Triple(
        itemIri,
        TaskOntologyConstants.textIri,
        _typeConverter.createStringLiteral(instance.text),
      ),
    );

    triples.add(
      Triple(
        itemIri,
        TaskOntologyConstants.isDeletedIri,
        _typeConverter.createBooleanLiteral(instance.isDeleted),
      ),
    );

    triples.add(
      Triple(
        itemIri,
        DcTermsConstants.createdIri,
        _typeConverter.createDateTimeLiteral(instance.createdAt),
      ),
    );

    triples.add(
      Triple(
        itemIri,
        DcTermsConstants.creatorIri,
        _typeConverter.createStringLiteral(instance.lastModifiedBy),
      ),
    );

    // Add vector clock entries
    for (final entry in instance.vectorClock.entries) {
      final clockEntryUri = TaskOntologyConstants.makeVectorClockEntryUri(
        instance.id,
        entry.key,
      );
      final clockEntryIri = IriTerm(clockEntryUri);

      // Add vector clock entry reference
      triples.add(
        Triple(itemIri, TaskOntologyConstants.vectorClockIri, clockEntryIri),
      );

      // Add vector clock entry type
      triples.add(
        Triple(
          clockEntryIri,
          RdfConstants.typeIri,
          TaskOntologyConstants.vectorClockEntryIri,
        ),
      );

      // Add client ID
      triples.add(
        Triple(
          clockEntryIri,
          TaskOntologyConstants.clientIdIri,
          _typeConverter.createStringLiteral(entry.key),
        ),
      );

      // Add clock value
      triples.add(
        Triple(
          clockEntryIri,
          TaskOntologyConstants.clockValueIri,
          _typeConverter.createIntegerLiteral(entry.value),
        ),
      );
    }

    return triples;
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
