import 'package:solid_task/ext/rdf/core/constants/xsd_constants.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf_orm/standard_mappers/base_rdf_literal_term_serializer.dart';

final class DateTimeSerializer extends BaseRdfLiteralTermSerializer<DateTime> {
  DateTimeSerializer({IriTerm? datatype})
    : super(
        datatype: datatype ?? XsdConstants.dateTimeIri,
        convertToString: (dateTime) => dateTime.toUtc().toIso8601String(),
      );
}
