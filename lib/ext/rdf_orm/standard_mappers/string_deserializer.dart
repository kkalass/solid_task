import 'package:solid_task/ext/rdf/core/constants/xsd_constants.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf_orm/standard_mappers/base_rdf_literal_term_deserializer.dart';

final class StringDeserializer extends BaseRdfLiteralTermDeserializer<String> {
  StringDeserializer({IriTerm? datatype})
    : super(
        datatype: datatype ?? XsdConstants.stringIri,
        convertFromLiteral: (term, _) => term.value,
      );
}
