import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf/core/graph/triple.dart';
import 'package:solid_task/ext/rdf_orm/serialization_context.dart';

abstract interface class RdfSubjectSerializer<T> {
  IriTerm get typeIri;
  (RdfSubject, List<Triple>) toRdfSubject(
    T value,
    SerializationContext context, {
    RdfSubject? parentSubject,
  });
}
