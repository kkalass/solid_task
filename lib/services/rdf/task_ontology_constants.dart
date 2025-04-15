import 'package:solid_task/services/rdf/rdf_graph.dart';

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
  static const taskClassIri = IriTerm('${namespace}Task');

  /// IRI for task text property
  static const textIri = IriTerm('${namespace}text');

  /// IRI for task isDeleted property
  static const isDeletedIri = IriTerm('${namespace}isDeleted');

  /// IRI for task vectorClock property
  static const vectorClockIri = IriTerm('${namespace}vectorClock');

  /// IRI for vectorClockEntry class
  static const vectorClockEntryIri = IriTerm('${namespace}vectorClockEntry');

  /// IRI for clientId property in vector clock entries
  static const clientIdIri = IriTerm('${namespace}clientId');

  /// IRI for clockValue property in vector clock entries
  static const clockValueIri = IriTerm('${namespace}clockValue');

  /// Base URI for task identifiers
  static const taskBaseUri = 'http://solidtask.org/tasks/';

  /// Creates a task URI from an ID
  static String makeTaskUri(String taskId) => '$taskBaseUri$taskId';

  /// Creates a vector clock entry URI for a specific task and client
  static String makeVectorClockEntryUri(String taskId, String clientId) =>
      '$taskBaseUri$taskId/vectorClock/$clientId';
}
