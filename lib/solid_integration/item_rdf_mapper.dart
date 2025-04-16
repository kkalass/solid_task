import 'package:solid_task/ext/rdf/core/constants/dc_terms_constants.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf/core/graph/triple.dart';
import 'package:solid_task/ext/rdf_orm/deserialization_context.dart';
import 'package:solid_task/ext/rdf_orm/exceptions/serialization_exception.dart';
import 'package:solid_task/ext/rdf_orm/rdf_subject_deserializer.dart';
import 'package:solid_task/ext/rdf_orm/rdf_subject_mapper.dart';
import 'package:solid_task/ext/rdf_orm/rdf_subject_serializer.dart';
import 'package:solid_task/ext/rdf_orm/serialization_context.dart';
import 'package:solid_task/ext/rdf_orm/standard_mappers/extracting_iri_term_deserializer.dart';
import 'package:solid_task/ext/rdf_orm/standard_mappers/iri_id_serializer.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/solid_integration/task_ontology_constants.dart';

// FIXME KK - register this class!

/// RDF mapper for Item domain objects
///
/// This class handles the conversion between Item domain objects and their
/// RDF representation, including vector clock entries for CRDT functionality.
final class ItemRdfMapper implements RdfSubjectMapper<Item> {
  @override
  final IriTerm typeIri = TaskOntologyConstants.taskClassIri;

  final ContextLogger _logger;

  /// Creates a new ItemRdfMapper
  ///
  /// @param loggerService Optional logger for diagnostic information
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

      // Note: serialization stores an IRI, we get the Id part of the IRI here
      lastModifiedBy: context.getRequiredPropertyValue<String>(
        iri,
        DcTermsConstants.creatorIri,
        iriDeserializer: AppInstanceIdDeserializer(),
      ),
    );

    item.id = TaskOntologyConstants.extractTaskIdFromIri(
      context.storageRoot,
      iri,
    );

    // Extract more properties
    item.createdAt = context.getRequiredPropertyValue<DateTime>(
      iri,
      DcTermsConstants.createdIri,
    );

    // Extract optional properties
    item.isDeleted =
        context.getPropertyValue<bool>(
          iri,
          TaskOntologyConstants.isDeletedIri,
        ) ??
        false;

    // Extract vector clock
    item.vectorClock = context.getPropertyValueMap(
      iri,
      TaskOntologyConstants.vectorClockIri,
      subjectDeserializer: VectorClockMapper(),
    );
    return item;
  }

  @override
  (RdfSubject, List<Triple>) toRdfSubject(
    Item instance,
    SerializationContext context, {
    RdfSubject? parentSubject,
  }) {
    _logger.debug('Converting Item ${instance.id} to triples');
    final itemIri = TaskOntologyConstants.makeTaskIri(
      context.storageRoot,
      instance.id,
    );

    return (
      itemIri,
      [
        // Add basic properties
        context.literal(itemIri, TaskOntologyConstants.textIri, instance.text),

        context.literal(
          itemIri,
          TaskOntologyConstants.isDeletedIri,
          instance.isDeleted,
        ),

        context.literal(
          itemIri,
          DcTermsConstants.createdIri,
          instance.createdAt,
        ),

        // creator always actually is the Id of the instance of the app,
        // and we create an IRI for this in order to be able to do more
        // with it in RDF, e.g. associate device name etc so that in theory
        // the user could later find out which device triggered a certain change etc.
        context.iri(
          itemIri,
          DcTermsConstants.creatorIri,
          instance.lastModifiedBy,
          serializer: AppInstanceIdSerializer(),
        ),

        // The vectorClock Map will be serialized as a list of Subjects in
        // their own rights, with the vectorClockIri predicate being the
        // connection from the item parent to the Subject children
        ...context.childSubjectMap(
          itemIri,
          TaskOntologyConstants.vectorClockIri,
          instance.vectorClock,
          VectorClockMapper(),
        ),
      ],
    );
  }
}

class AppInstanceIdDeserializer extends ExtractingIriTermDeserializer<String> {
  AppInstanceIdDeserializer()
    : super(
        extract:
            (term, ctxt) => TaskOntologyConstants.extractAppInstanceIdFromIri(
              ctxt.storageRoot,
              term,
            ),
      );
}

class AppInstanceIdSerializer extends IriIdSerializer {
  AppInstanceIdSerializer()
    : super(
        expand:
            (appInstanceId, context) =>
                TaskOntologyConstants.makeAppInstanceIri(
                  context.storageRoot,
                  appInstanceId,
                ),
      );
}

class VectorClockMapper
    implements
        RdfSubjectDeserializer<MapEntry<String, int>>,
        RdfSubjectSerializer<MapEntry<String, int>> {
  @override
  final IriTerm typeIri = TaskOntologyConstants.vectorClockEntryIri;

  @override
  fromIriTerm(IriTerm clockEntryIri, DeserializationContext context) {
    return MapEntry(
      context.getRequiredPropertyValue<String>(
        clockEntryIri,
        TaskOntologyConstants.clientIdIri,
        iriDeserializer: AppInstanceIdDeserializer(),
      ),
      context.getRequiredPropertyValue<int>(
        clockEntryIri,
        TaskOntologyConstants.clockValueIri,
      ),
    );
  }

  @override
  (RdfSubject, List<Triple>) toRdfSubject(
    MapEntry<String, int> entry,
    SerializationContext context, {
    RdfSubject? parentSubject,
  }) {
    if (parentSubject == null || parentSubject is! IriTerm) {
      throw SerializationException(
        "Vector Clock can only be created for a concrete parent that has an IriTerm, not for $parentSubject",
      );
    }
    var iri = TaskOntologyConstants.makeVectorClockEntryIriFromParentIri(
      parentSubject,
      entry.key,
    );

    return (
      iri,
      [
        // The actual vector clock entry

        // the reference to the app instance which created the version
        context.iri(
          iri,
          TaskOntologyConstants.clientIdIri,
          entry.key,
          serializer: AppInstanceIdSerializer(),
        ),

        // the version counter
        context.literal(iri, TaskOntologyConstants.clockValueIri, entry.value),
      ],
    );
  }
}
