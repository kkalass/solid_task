import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf_orm/deserialization_context.dart';
import 'package:solid_task/ext/rdf_orm/rdf_iri_term_deserializer.dart';

final class IriFullDeserializer implements RdfIriTermDeserializer<String> {
  @override
  fromIriTerm(IriTerm term, DeserializationContext context) {
    return term.iri;
  }
}
