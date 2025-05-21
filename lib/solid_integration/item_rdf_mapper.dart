import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:rdf_vocabularies/dcterms.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/solid_integration/task_ontology_constants.dart';

/// RDF mapper for Item domain objects
///
/// This class handles the conversion between Item domain objects and their
/// RDF representation, including vector clock entries for CRDT functionality.
final class ItemRdfMapper implements GlobalResourceMapper<Item> {
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
  Item fromRdfResource(IriTerm iri, DeserializationContext context) {
    _logger.debug('Converting triples to Item with subject: $iri');
    final reader = context.reader(iri);

    final storageRoot = _storageRootProvider();
    // Create base item
    return Item(
        text: reader.require<String>(TaskOntologyConstants.textIri),

        // Note: serialization stores an IRI, we get the Id part of the IRI here
        lastModifiedBy: reader.require(
          Dcterms.creator,
          iriTermDeserializer: AppInstanceIdDeserializer(
            storageRoot: storageRoot,
          ),
        ),
      )
      ..id = TaskOntologyConstants.extractTaskIdFromIri(storageRoot, iri)
      ..createdAt = reader.require<DateTime>(Dcterms.created)
      ..isDeleted =
          reader.optional<bool>(TaskOntologyConstants.isDeletedIri) ?? false
      ..vectorClock = reader.getMap(
        TaskOntologyConstants.vectorClockIri,
        globalResourceDeserializer: VectorClockMapper(storageRoot: storageRoot),
      );
  }

  @override
  (IriTerm, List<Triple>) toRdfResource(
    Item instance,
    SerializationContext context, {
    RdfSubject? parentSubject,
  }) {
    _logger.debug('Converting Item ${instance.id} to triples');
    final storageRoot = _storageRootProvider();
    final itemIri = TaskOntologyConstants.makeTaskIri(storageRoot, instance.id);

    return context
        .resourceBuilder(itemIri)
        .addValue(TaskOntologyConstants.textIri, instance.text)
        .addValue(TaskOntologyConstants.isDeletedIri, instance.isDeleted)
        .addValue(Dcterms.created, instance.createdAt)
        .addValue(
          Dcterms.creator,
          instance.lastModifiedBy,
          // creator always actually is the Id of the instance of the app,
          // and we create an IRI for this in order to be able to do more
          // with it in RDF, e.g. associate device name etc so that in theory
          // the user could later find out which device triggered a certain change etc.
          iriTermSerializer: AppInstanceIdSerializer(storageRoot: storageRoot),
        )
        .addMap(
          TaskOntologyConstants.vectorClockIri,
          instance.vectorClock,
          resourceSerializer: VectorClockMapper(storageRoot: storageRoot),
        )
        .build();
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

class VectorClockMapper implements GlobalResourceMapper<MapEntry<String, int>> {
  final String storageRoot;
  @override
  final IriTerm typeIri = TaskOntologyConstants.vectorClockEntryIri;

  VectorClockMapper({required this.storageRoot});

  @override
  MapEntry<String, int> fromRdfResource(
    IriTerm clockEntryIri,
    DeserializationContext context,
  ) {
    final reader = context.reader(clockEntryIri);
    return MapEntry(
      reader.require(
        TaskOntologyConstants.clientIdIri,
        iriTermDeserializer: AppInstanceIdDeserializer(
          storageRoot: storageRoot,
        ),
      ),
      reader.require(TaskOntologyConstants.clockValueIri),
    );
  }

  @override
  (IriTerm, List<Triple>) toRdfResource(
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

    // Build the actual vector clock map entry
    return context
        .resourceBuilder(iri)
        // the reference to the app instance which created the version
        .addValue(
          TaskOntologyConstants.clientIdIri,
          entry.key,
          iriTermSerializer: AppInstanceIdSerializer(storageRoot: storageRoot),
        )
        // the version counter
        .addValue(TaskOntologyConstants.clockValueIri, entry.value)
        .build();
  }
}
