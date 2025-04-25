import 'package:rdf_core/constants/dc_terms_constants.dart';
import 'package:rdf_core/graph/rdf_term.dart';
import 'package:rdf_core/graph/triple.dart';
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

/// RDF mapper for Item domain objects
///
/// This class handles the conversion between Item domain objects and their
/// RDF representation, including vector clock entries for CRDT functionality.
final class ItemRdfMapper implements RdfSubjectMapper<Item> {
  @override
  final IriTerm typeIri = TaskOntologyConstants.taskClassIri;
  final String Function() _storageRootProvider;
  final ContextLogger _logger;

  /// Creates a new ItemRdfMapper
  ///
  /// @param loggerService Optional logger for diagnostic information
  ItemRdfMapper({
    LoggerService? loggerService,
    required String Function() storageRootProvider,
  }) : _logger = (loggerService ?? LoggerService()).createLogger(
         'ItemRdfMapper',
       ),
       _storageRootProvider = storageRootProvider;

  @override
  Item fromIriTerm(IriTerm iri, DeserializationContext context) {
    _logger.debug('Converting triples to Item with subject: $iri');

    final storageRoot = _storageRootProvider();
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
        iriDeserializer: AppInstanceIdDeserializer(storageRoot: storageRoot),
      ),
    );

    item.id = TaskOntologyConstants.extractTaskIdFromIri(storageRoot, iri);

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
      subjectDeserializer: VectorClockMapper(storageRoot: storageRoot),
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
    final storageRoot = _storageRootProvider();
    final itemIri = TaskOntologyConstants.makeTaskIri(storageRoot, instance.id);

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
          serializer: AppInstanceIdSerializer(storageRoot: storageRoot),
        ),

        // The vectorClock Map will be serialized as a list of Subjects in
        // their own rights, with the vectorClockIri predicate being the
        // connection from the item parent to the Subject children
        ...context.childSubjectMap(
          itemIri,
          TaskOntologyConstants.vectorClockIri,
          instance.vectorClock,
          VectorClockMapper(storageRoot: storageRoot),
        ),
      ],
    );
  }
}

class AppInstanceIdDeserializer extends ExtractingIriTermDeserializer<String> {
  final String storageRoot;
  AppInstanceIdDeserializer({required this.storageRoot})
    : super(
        extract:
            (term, ctxt) => TaskOntologyConstants.extractAppInstanceIdFromIri(
              storageRoot,
              term,
            ),
      );
}

class AppInstanceIdSerializer extends IriIdSerializer {
  final String storageRoot;
  AppInstanceIdSerializer({required this.storageRoot})
    : super(
        expand:
            (appInstanceId, context) =>
                TaskOntologyConstants.makeAppInstanceIri(
                  storageRoot,
                  appInstanceId,
                ),
      );
}

class VectorClockMapper implements RdfSubjectMapper<MapEntry<String, int>> {
  final String storageRoot;
  @override
  final IriTerm typeIri = TaskOntologyConstants.vectorClockEntryIri;

  VectorClockMapper({required this.storageRoot});

  @override
  fromIriTerm(IriTerm clockEntryIri, DeserializationContext context) {
    return MapEntry(
      context.getRequiredPropertyValue<String>(
        clockEntryIri,
        TaskOntologyConstants.clientIdIri,
        iriDeserializer: AppInstanceIdDeserializer(storageRoot: storageRoot),
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
          serializer: AppInstanceIdSerializer(storageRoot: storageRoot),
        ),

        // the version counter
        context.literal(iri, TaskOntologyConstants.clockValueIri, entry.value),
      ],
    );
  }
}
