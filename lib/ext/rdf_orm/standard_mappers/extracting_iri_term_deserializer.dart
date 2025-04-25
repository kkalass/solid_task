import 'package:rdf_core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf_orm/deserialization_context.dart';
import 'package:solid_task/ext/rdf_orm/exceptions/deserialization_exception.dart';
import 'package:solid_task/ext/rdf_orm/rdf_iri_term_deserializer.dart';

class ExtractingIriTermDeserializer<T> implements RdfIriTermDeserializer<T> {
  final T Function(IriTerm, DeserializationContext) _extract;

  ExtractingIriTermDeserializer({
    required T Function(IriTerm, DeserializationContext) extract,
  }) : _extract = extract;

  @override
  fromIriTerm(IriTerm term, DeserializationContext context) {
    try {
      return _extract(term, context);
    } on DeserializationException {
      rethrow;
    } catch (e) {
      throw DeserializationException(
        'Failed to parse Iri Id from ${T.toString()}: ${term.iri}. Error: $e',
      );
    }
  }
}
