import 'package:solid_task/services/rdf/mapping/rdf_mapper_registry.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';

class DeserializerNotFoundException extends RdfMappingException {
  final String _t;
  final String _serializerType;

  DeserializerNotFoundException(this._serializerType, Type type)
    : _t = type.toString();

  DeserializerNotFoundException.forTypeIri(this._serializerType, IriTerm type)
    : _t = type.iri;

  @override
  String toString() =>
      'DeserializerNotFoundException: (No $_serializerType Deserializer found for $_t)';
}

class SerializerNotFoundException extends RdfMappingException {
  final Type _t;
  final String _serializerType;
  SerializerNotFoundException(this._serializerType, this._t);

  @override
  String toString() =>
      'SerializerNotFoundException: (No $_serializerType Serializer found for ${_t.toString()})';
}
