import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf_orm/deserialization_context.dart';

abstract class RdfBlankNodeTermDeserializer<T> {
  T fromBlankNodeTerm(BlankNodeTerm term, DeserializationContext context);
}
