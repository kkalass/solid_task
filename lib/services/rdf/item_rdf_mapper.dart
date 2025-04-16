import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/mapping/rdf_mapper_registry.dart';
import 'package:solid_task/services/rdf/rdf_constants.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:solid_task/services/rdf/task_ontology_constants.dart';

// FIXME KK - register this class!

/// RDF mapper for Item domain objects
///
/// This class handles the conversion between Item domain objects and their
/// RDF representation, including vector clock entries for CRDT functionality.
final class ItemRdfMapper
    implements RdfIriTermDeserializer<Item>, RdfToTriplesSerializer<Item> {
  final ContextLogger _logger;

  /// Creates a new ItemRdfMapper
  ///
  /// @param loggerService Optional logger for diagnostic information
  /// @param typeConverter Type converter for RDF literals (will be created if not provided)
  ItemRdfMapper({LoggerService? loggerService})
    : _logger = (loggerService ?? LoggerService()).createLogger(
        'ItemRdfMapper',
      );

  @override
  Item fromIriTerm(IriTerm iri, DeserializationContext context) {
    _logger.debug('Converting triples to Item with subject: $iri');

    // Create base item
    final item = Item(
      text: context.getRequiredPropertyValue<String>(
        iri,
        TaskOntologyConstants.textIri,
      ),
      // Note: when serialization stores an IRI, we will get the Id part of the IRI here
      lastModifiedBy: context.getRequiredPropertyValue<String>(
        iri,
        DcTermsConstants.creatorIri,
        iriDeserializer: IriIdStringDeserializer(
          expectedSubjectBaseIri: TaskOntologyConstants.appInstanceBaseUri,
        ),
      ),
    );
    item.id = IriIdStringDeserializer(
      expectedSubjectBaseIri: TaskOntologyConstants.taskBaseUri,
    ).fromIriTerm(iri, context);

    // Extract more properties
    item.createdAt = context.getRequiredPropertyValue<DateTime>(
      iri,
      DcTermsConstants.createdIri,
    );

    // Extract optional properties
    item.isDeleted =
        context.getPropertyValue(iri, TaskOntologyConstants.isDeletedIri) ??
        false;

    // Extract vector clock
    item.vectorClock = Map<String, int>.fromEntries(
      context.getPropertyValues(
        iri,
        TaskOntologyConstants.vectorClockIri,
        iriDeserializer: VectorClockDeserializer(),
      ),
    );
    return item;
  }

  @override
  List<Triple> toTriples(Item instance, SerializationContext context) {
    _logger.debug('Converting Item ${instance.id} to triples');
    final itemIri = TaskOntologyConstants.makeTaskIri(instance.id);

    return [
      // Add rdf:type
      Triple(itemIri, RdfConstants.typeIri, TaskOntologyConstants.taskClassIri),

      // Add basic properties
      Triple(
        itemIri,
        TaskOntologyConstants.textIri,
        context.toLiteral(instance.text),
      ),

      Triple(
        itemIri,
        TaskOntologyConstants.isDeletedIri,
        context.toLiteral(instance.isDeleted),
      ),

      Triple(
        itemIri,
        DcTermsConstants.createdIri,
        context.toLiteral(instance.createdAt),
      ),

      Triple(
        itemIri,
        DcTermsConstants.creatorIri,
        // creator always actually is the Id of the instance of the app,
        // and we create an IRI for this in order to be able to do more
        // with it in RDF, e.g. associate device name etc so that in theory
        // the user could later find out which device triggered a certain change etc.
        context.toIri(
          instance.lastModifiedBy,
          serializer: IriIdSerializer(
            baseIri: TaskOntologyConstants.appInstanceBaseUri,
          ),
        ),
      ),

      // Store the vector clock map as one RDF Subject per entry and associate
      // those new vector clock subject as objects with the Item Subject.
      ...instance.vectorClock.entries.expand((entry) {
        var clockEntryIri = TaskOntologyConstants.makeVectorClockEntryIri(
          instance.id,
          entry.key,
        );
        return [
          // The actual Vector Clock Entry
          ...context.toTriples(
            entry,
            serializer: VectorClockSerializer(clockEntryIri: clockEntryIri),
          ),

          // Link from Item to Vector Clock Entry
          Triple(itemIri, TaskOntologyConstants.vectorClockIri, clockEntryIri),
        ];
      }),
    ];
  }
}

class VectorClockSerializer
    implements RdfToTriplesSerializer<MapEntry<String, int>> {
  final IriTerm _clockEntryIri;

  VectorClockSerializer({required IriTerm clockEntryIri})
    : _clockEntryIri = clockEntryIri;

  @override
  List<Triple> toTriples(
    MapEntry<String, int> entry,
    SerializationContext context,
  ) {
    return [
      // The actual vector clock entry
      Triple(
        _clockEntryIri,
        RdfConstants.typeIri,
        TaskOntologyConstants.vectorClockEntryIri,
      ),
      Triple(
        _clockEntryIri,
        TaskOntologyConstants.clientIdIri,
        context.toLiteral(entry.key),
      ),
      Triple(
        _clockEntryIri,
        TaskOntologyConstants.clockValueIri,
        context.toLiteral(entry.value),
      ),
    ];
  }
}

class VectorClockDeserializer
    implements RdfIriTermDeserializer<MapEntry<String, int>> {
  @override
  fromIriTerm(IriTerm clockEntryIri, DeserializationContext context) {
    return MapEntry(
      context.getRequiredPropertyValue<String>(
        clockEntryIri,
        TaskOntologyConstants.clientIdIri,
      ),
      context.getRequiredPropertyValue<int>(
        clockEntryIri,
        TaskOntologyConstants.clockValueIri,
      ),
    );
  }
}
