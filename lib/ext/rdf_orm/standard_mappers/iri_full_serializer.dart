import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf_orm/rdf_iri_term_serializer.dart';
import 'package:solid_task/ext/rdf_orm/serialization_context.dart';

final class IriFullSerializer implements RdfIriTermSerializer<String> {
  @override
  toIriTerm(String iri, SerializationContext context) {
    return IriTerm(iri);
  }
}
