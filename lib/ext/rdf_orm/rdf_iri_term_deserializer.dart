import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf_orm/deserialization_context.dart';

abstract interface class RdfIriTermDeserializer<T> {
  T fromIriTerm(IriTerm term, DeserializationContext context);
}
