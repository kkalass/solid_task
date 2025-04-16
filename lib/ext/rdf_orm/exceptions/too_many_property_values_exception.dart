import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf_orm/exceptions/rdf_mapping_exception.dart';

class TooManyPropertyValuesException extends RdfMappingException {
  final RdfSubject subject;
  final RdfPredicate predicate;
  final List<RdfObject> objects;

  TooManyPropertyValuesException({
    required this.subject,
    required this.predicate,
    required this.objects,
  });

  @override
  String toString() =>
      'TooManyPropertyValuesException: Found ${objects.length} Objects, but expected only one. (Subject: $subject, Predicate: $predicate)';
}
