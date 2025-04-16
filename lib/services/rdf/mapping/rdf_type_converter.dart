import 'package:solid_task/services/rdf/mapping/rdf_mapper_registry.dart';

class DeserializerNotFoundException extends RdfMappingException {
  final Type _t;
  final String _serializerType;
  DeserializerNotFoundException(this._serializerType, this._t);

  @override
  String toString() =>
      'DeserializerNotFoundException: (No $_serializerType Deserializer found for ${_t.toString()})';
}

class SerializerNotFoundException extends RdfMappingException {
  final Type _t;
  final String _serializerType;
  SerializerNotFoundException(this._serializerType, this._t);

  @override
  String toString() =>
      'SerializerNotFoundException: (No $_serializerType Serializer found for ${_t.toString()})';
}
