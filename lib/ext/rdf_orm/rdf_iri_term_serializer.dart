import 'package:rdf_core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf_orm/serialization_context.dart';

abstract interface class RdfIriTermSerializer<T> {
  IriTerm toIriTerm(T value, SerializationContext context);
}
