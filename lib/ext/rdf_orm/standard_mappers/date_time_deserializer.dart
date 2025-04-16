import 'package:solid_task/ext/rdf/core/constants/xsd_constants.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf_orm/standard_mappers/base_rdf_literal_term_deserializer.dart';

final class DateTimeDeserializer
    extends BaseRdfLiteralTermDeserializer<DateTime> {
  DateTimeDeserializer({IriTerm? datatype})
    : super(
        datatype: datatype ?? XsdConstants.dateTimeIri,
        convertFromLiteral: (term, _) => DateTime.parse(term.value).toUtc(),
      );
}
