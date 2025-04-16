import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf_orm/serialization_context.dart';

abstract class RdfLiteralTermSerializer<T> {
  LiteralTerm toLiteralTerm(T value, SerializationContext context);
}
