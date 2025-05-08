import 'package:rdf_core/rdf_core.dart';

/// Ontology constants specific to SolidTask domain
///
/// This class provides common IRIs used in the SolidTask application's RDF model.
/// All terms follow the application's ontology design.
class TaskOntologyConstants {
  /// Private constructor to prevent instantiation
  const TaskOntologyConstants._();

  /// Base IRI for task ontology
  static const String namespace = 'http://solidtask.org/ontology#';

  /// IRI for the Task class
  static const taskClassIri = IriTerm.prevalidated('${namespace}Task');

  /// IRI for task text property
  static const textIri = IriTerm.prevalidated('${namespace}text');

  /// IRI for task isDeleted property
  static const isDeletedIri = IriTerm.prevalidated('${namespace}isDeleted');

  /// IRI for task vectorClock property
  static const vectorClockIri = IriTerm.prevalidated('${namespace}vectorClock');

  /// IRI for vectorClockEntry class
  static const vectorClockEntryIri = IriTerm.prevalidated(
    '${namespace}VectorClockEntry',
  );

  /// IRI for clientId property in vector clock entries
  static const clientIdIri = IriTerm.prevalidated('${namespace}clientId');

  /// IRI for clockValue property in vector clock entries
  static const clockValueIri = IriTerm.prevalidated('${namespace}clockValue');

  static String makeAppBaseUri(String storageRoot) =>
      '${storageRoot}solidtask/';
  static String makeTaskBaseUri(String storageRoot) =>
      '${makeAppBaseUri(storageRoot)}task/';

  static IriTerm makeTaskIri(String storageRoot, String taskId) =>
      IriTerm.prevalidated('${makeTaskBaseUri(storageRoot)}$taskId.ttl');

  /// Extracts the taskId from a task IRI that was created using makeTaskIri
  ///
  /// Returns null if the IRI doesn't match the expected task IRI pattern
  /// Private helper to extract an ID from an IRI based on a prefix pattern and file extension
  static String _extractLastPart(String prefix, IriTerm iri, {String? ending}) {
    if (!iri.iri.startsWith(prefix)) {
      throw Exception(
        "IRI ${iri.iri} doesn't match the expected base URI format: $prefix",
      );
    }

    // Extract the remainder after the base path
    final remainingPath = iri.iri.substring(prefix.length);

    final String lastPart;
    if (ending != null) {
      // Extract everything before .ttl extension
      final endingIndex = remainingPath.lastIndexOf(ending);
      lastPart = remainingPath.substring(0, endingIndex);
    } else {
      lastPart = remainingPath;
    }
    // Validate pattern - should be directly a filename
    if (!RegExp(r'^[^/]+$').hasMatch(lastPart)) {
      throw Exception(
        "Invalid  IRI format: ${iri.iri}. Expected: $prefix<id>${ending ?? ''}",
      );
    }
    return lastPart;
  }

  static String extractTaskIdFromIri(String storageRoot, IriTerm iri) {
    final taskBaseUri = makeTaskBaseUri(storageRoot);
    return _extractLastPart(taskBaseUri, iri, ending: '.ttl');
  }

  static String extractVectorClockEntryKey(
    String storageRoot,
    IriTerm iri,
    String taskId,
  ) {
    final vectorClockBaseUri = makeVectorClockBaseUri(storageRoot, taskId);
    return _extractLastPart(vectorClockBaseUri, iri);
  }

  static IriTerm makeVectorClockEntryIri(
    String storageRoot,
    String taskId,
    String entryKey,
  ) => IriTerm.prevalidated(
    '${makeVectorClockBaseUri(storageRoot, taskId)}$entryKey',
  );

  static IriTerm makeVectorClockEntryIriFromParentIri(
    IriTerm parentIri,
    String entryKey,
  ) => IriTerm.prevalidated(
    '${makeVectorClockBaseUriFromParentIri(parentIri)}$entryKey',
  );

  static String makeAppInstanceBaseUri(String storageRoot) =>
      '${makeAppBaseUri(storageRoot)}appinstance/';
  static IriTerm makeAppInstanceIri(String storageRoot, String appInstanceId) =>
      IriTerm.prevalidated(
        '${makeAppInstanceBaseUri(storageRoot)}$appInstanceId.ttl',
      );

  /// Extracts the appInstanceId from an app instance IRI that was created using makeAppInstanceIri
  ///
  /// Returns null if the IRI doesn't match the expected app instance IRI pattern
  static String extractAppInstanceIdFromIri(String storageRoot, IriTerm iri) {
    // Construct the expected app instance base URI pattern
    final expectedPrefix = makeAppInstanceBaseUri(storageRoot);
    return _extractLastPart(expectedPrefix, iri, ending: '.ttl');
  }

  static String makeVectorClockBaseUriFromParentIri(IriTerm parentIri) =>
      '${parentIri.iri}#vectorclock/';

  static String makeVectorClockBaseUri(String storageRoot, String taskId) =>
      makeVectorClockBaseUriFromParentIri(makeTaskIri(storageRoot, taskId));
}
