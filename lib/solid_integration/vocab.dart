import 'package:rdf_core/rdf_core.dart';

// -- Our ontology class provided by us --
class SolidTask {
  /// Private constructor to prevent instantiation
  const SolidTask._();

  /// Base IRI for task ontology
  static const String namespace = 'http://solidtask.org/ontology#';

  /// IRI for the Task class
  // ignore: constant_identifier_names
  static const Task = IriTerm.prevalidated('${namespace}Task');

  /// IRI for VectorClockEntry class
  // ignore: constant_identifier_names
  static const VectorClockEntry = IriTerm.prevalidated(
    '${namespace}VectorClockEntry',
  );

  /// IRI for task text property
  static const text = IriTerm.prevalidated('${namespace}text');

  /// IRI for task isDeleted property
  static const isDeleted = IriTerm.prevalidated('${namespace}isDeleted');

  /// IRI for task vectorClock property
  static const vectorClock = IriTerm.prevalidated('${namespace}vectorClock');

  /// IRI for clientId property in vector clock entries
  static const clientId = IriTerm.prevalidated('${namespace}clientId');

  /// IRI for clockValue property in vector clock entries
  static const clockValue = IriTerm.prevalidated('${namespace}clockValue');
}

class SolidTaskTask {
  /// Private constructor to prevent instantiation
  const SolidTaskTask._();

  /// Base IRI for task ontology
  static const classIri = SolidTask.Task;

  /// IRI for task text property
  static const text = SolidTask.text;

  /// IRI for task isDeleted property
  static const isDeleted = SolidTask.isDeleted;

  /// IRI for task vectorClock property
  static const vectorClock = SolidTask.vectorClock;
}

class SolidTaskVectorClockEntry {
  /// Private constructor to prevent instantiation
  const SolidTaskVectorClockEntry._();

  /// Base IRI for task ontology
  static const classIri = SolidTask.VectorClockEntry;

  static const clientId = SolidTask.clientId;

  static const clockValue = SolidTask.clockValue;
}
