import 'package:solid_task/ext/rdf_orm/rdf_subject_deserializer.dart';
import 'package:solid_task/ext/rdf_orm/rdf_subject_serializer.dart';

abstract interface class RdfSubjectMapper<T>
    implements RdfSubjectDeserializer<T>, RdfSubjectSerializer<T> {}
