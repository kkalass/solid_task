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

  // FIXME KK - the base URI should be a directory in the users
  // pod and thus cannot be a constant.
  // FIXME KK - create an application root folder in the solid pod and use that as namespace for data managed by our app
  /// Base URI for task identifiers
  static const taskBaseUri = 'http://solidtask.org/tasks/';

  /// Creates a task URI from an ID
  static IriTerm makeTaskIri(String taskId) => IriTerm('$taskBaseUri$taskId');

  /// Creates a vector clock entry URI for a specific task and client
  static String makeVectorClockBaseUri(String taskId) =>
      '$taskBaseUri$taskId/vectorClock/';

  static IriTerm makeVectorClockEntryIri(String taskId, String clientId) =>
      IriTerm('${makeVectorClockBaseUri(taskId)}$clientId');

  /// Base URI for app instance identifiers
  static const appInstanceBaseUri = 'http://solidtask.org/appinstance/';
}
