import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/mapping/rdf_type_converter.dart';
import 'package:solid_task/services/rdf/rdf_constants.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';

/// Context for serialization operations
///
/// Provides access to services and state needed during RDF serialization.
/// Used to delegate complex type mapping to the parent service.
abstract interface class SerializationContext {
  /// Maps an object to RDF triples using an appropriate mapper
  ///
  /// @param instance The object to convert
  /// @return List of RDF triples representing the object
  List<Triple> toTriples<T>(
    T instance, {
    RdfToTriplesSerializer<T>? serializer,
  });

  LiteralTerm toLiteral<T>(
    T instance, {
    RdfLiteralTermSerializer<T>? serializer,
  });

  BlankNodeTerm toBlankNode<T>(
    T instance, {
    RdfBlankNodeTermSerializer<T>? serializer,
  });

  IriTerm toIri<T>(T instance, {RdfIriTermSerializer<T>? serializer});
}

/// Context for deserialization operations
///
/// Provides access to services and state needed during RDF deserialization.
/// Used to delegate complex type reconstruction to the parent service.
abstract interface class DeserializationContext {
  /// Gets a property value from the RDF graph
  ///
  /// In RDF, we have triples of "subject", "predicate", "object".
  /// Translated to pure dart, the subject is the object we are working with,
  /// the predicate is the property we are looking for, and the object is
  /// the value we are looking for.
  ///
  /// @param subject The subject IRI of the object we are working with
  /// @param predicate The predicate IRI of the property
  /// @param failOnMultivalue If true, we will throw an exception if there is more than one matching term.
  /// @return The object value of the property
  T getRequiredPropertyValue<T>(
    RdfSubject subject,
    RdfPredicate predicate, {
    bool enforceSingleValue = true,
    RdfIriTermDeserializer<T>? iriDeserializer,
    RdfLiteralTermDeserializer<T>? literalDeserializer,
    RdfBlankNodeTermDeserializer<T>? blankNodeDeserializer,
  });

  T? getPropertyValue<T>(
    RdfSubject subject,
    RdfPredicate predicate, {
    bool enforceSingleValue = true,
    RdfIriTermDeserializer<T>? iriDeserializer,
    RdfLiteralTermDeserializer<T>? literalDeserializer,
    RdfBlankNodeTermDeserializer<T>? blankNodeDeserializer,
  });

  List<T> getPropertyValues<T>(
    RdfSubject subject,
    RdfPredicate predicate, {
    RdfIriTermDeserializer<T>? iriDeserializer,
    RdfLiteralTermDeserializer<T>? literalDeserializer,
    RdfBlankNodeTermDeserializer<T>? blankNodeDeserializer,
  });
}

class RdfMappingException implements Exception {
  final String? _message;

  RdfMappingException({String? message}) : _message = message;

  @override
  String toString() =>
      _message != null ? "$runtimeType: $_message" : runtimeType.toString();
}

/// Exception thrown when a required property value is not found in the RDF graph
///
/// Used during deserialization when a required property is missing from the data.
class PropertyValueNotFoundException extends RdfMappingException {
  final RdfSubject subject;
  final RdfPredicate predicate;

  /// Creates a new PropertyValueNotFoundException
  ///
  /// @param message Description of the error
  /// @param subject The subject IRI where the property was expected
  /// @param predicate The predicate IRI of the missing property
  PropertyValueNotFoundException({
    required this.subject,
    required this.predicate,
  });

  @override
  String toString() =>
      'PropertyValueNotFoundException: (Subject: $subject, Predicate: $predicate)';
}

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

class SerializationContextImpl extends SerializationContext {
  final RdfMapperRegistry _registry;

  SerializationContextImpl({required RdfMapperRegistry registry})
    : _registry = registry;

  @override
  List<Triple> toTriples<T>(T instance, String subjectUri) {
    // TODO: implement mapToTriples
    throw UnimplementedError();
  }
}

class DeserializationContextImpl extends DeserializationContext {
  final RdfGraph _graph;
  final RdfMapperRegistry _registry;

  DeserializationContextImpl({
    required RdfGraph graph,
    required RdfMapperRegistry registry,
  }) : _graph = graph,
       _registry = registry;

  T fromRdf<T>(
    RdfTerm term,
    RdfIriTermDeserializer<T>? iriDeserializer,
    RdfLiteralTermDeserializer<T>? literalDeserializer,
    RdfBlankNodeTermDeserializer<T>? blankNodeDeserializer,
  ) {
    var context = this;
    switch (term) {
      case IriTerm _:
        if (iriDeserializer != null) {
          return iriDeserializer.fromIriTerm(term, context);
        }
        return _registry.getIriDeserializer<T>().fromIriTerm(term, context);
      case LiteralTerm _:
        if (literalDeserializer != null) {
          return literalDeserializer.fromLiteralTerm(term, context);
        }
        return _registry.getLiteralDeserializer<T>().fromLiteralTerm(
          term,
          context,
        );
      case BlankNodeTerm _:
        if (blankNodeDeserializer != null) {
          return blankNodeDeserializer.fromBlankNodeTerm(term, context);
        }
        return _registry.getBlankNodeDeserializer<T>().fromBlankNodeTerm(
          term,
          context,
        );
    }
  }

  @override
  T? getPropertyValue<T>(
    RdfSubject subject,
    RdfPredicate predicate, {
    bool enforceSingleValue = true,
    RdfIriTermDeserializer<T>? iriDeserializer,
    RdfLiteralTermDeserializer<T>? literalDeserializer,
    RdfBlankNodeTermDeserializer<T>? blankNodeDeserializer,
  }) {
    final triples = _graph.findTriples(subject: subject, predicate: predicate);

    if (enforceSingleValue && triples.length > 1) {
      throw TooManyPropertyValuesException(
        subject: subject,
        predicate: predicate,
        objects: triples.map((t) => t.object).toList(),
      );
    }

    final rdfObject = triples.first.object;
    return fromRdf(
      rdfObject,
      iriDeserializer,
      literalDeserializer,
      blankNodeDeserializer,
    );
  }

  @override
  List<T> getPropertyValues<T>(
    RdfSubject subject,
    RdfPredicate predicate, {
    RdfIriTermDeserializer<T>? iriDeserializer,
    RdfLiteralTermDeserializer<T>? literalDeserializer,
    RdfBlankNodeTermDeserializer<T>? blankNodeDeserializer,
  }) {
    final triples = _graph.findTriples(subject: subject, predicate: predicate);
    return triples
        .map(
          (triple) => fromRdf(
            triple.object,
            iriDeserializer,
            literalDeserializer,
            blankNodeDeserializer,
          ),
        )
        .toList();
  }

  @override
  T getRequiredPropertyValue<T>(
    RdfSubject subject,
    RdfPredicate predicate, {
    bool enforceSingleValue = true,
    RdfIriTermDeserializer<T>? iriDeserializer,
    RdfLiteralTermDeserializer<T>? literalDeserializer,
    RdfBlankNodeTermDeserializer<T>? blankNodeDeserializer,
  }) {
    var result = getPropertyValue(
      subject,
      predicate,
      enforceSingleValue: enforceSingleValue,
      iriDeserializer: iriDeserializer,
      literalDeserializer: literalDeserializer,
      blankNodeDeserializer: blankNodeDeserializer,
    );
    if (result == null) {
      throw PropertyValueNotFoundException(
        subject: subject,
        predicate: predicate,
      );
    }
    return result;
  }
}

abstract interface class RdfIriTermDeserializer<T> {
  T fromIriTerm(IriTerm term, DeserializationContext context);
}

abstract class RdfBlankNodeTermDeserializer<T> {
  T fromBlankNodeTerm(BlankNodeTerm term, DeserializationContext context);
}

abstract class RdfLiteralTermDeserializer<T> {
  T fromLiteralTerm(LiteralTerm term, DeserializationContext context);
}

abstract class BaseRdfLiteralTermDeserializer<T>
    implements RdfLiteralTermDeserializer<T> {
  final IriTerm _datatype;
  final T Function(LiteralTerm term, DeserializationContext context)
  _convertFromLiteral;

  BaseRdfLiteralTermDeserializer({
    required IriTerm datatype,
    required T Function(LiteralTerm term, DeserializationContext context)
    convertFromLiteral,
  }) : _datatype = datatype,
       _convertFromLiteral = convertFromLiteral;

  @override
  T fromLiteralTerm(LiteralTerm term, DeserializationContext context) {
    if (term.datatype != _datatype) {
      throw DeserializationException(
        message:
            'Failed to parse ${T.toString()}: ${term.value}. Error: The expected datatype is ${_datatype.iri} but the actual datatype in the Literal was ${term.datatype.iri}',
      );
    }
    try {
      return _convertFromLiteral(term, context);
    } catch (e) {
      throw DeserializationException(
        message: 'Failed to parse ${T.toString()}: ${term.value}. Error: $e',
      );
    }
  }
}

abstract class RdfLiteralTermSerializer<T> {
  LiteralTerm toLiteralTerm(T value, SerializationContext context);
}

// FIXME KK better name?
abstract interface class RdfToTriplesSerializer<T> {
  List<Triple> toTriples(T value, SerializationContext context);
}

// FIXME KK - needed?
@deprecated
abstract interface class RdfIriTermSerializer<T> {
  IriTerm toIriTerm(T value, SerializationContext context);
}

abstract interface class RdfBlankNodeTermSerializer<T> {
  BlankNodeTerm toBlankNode(T value, SerializationContext context);
}

abstract class BaseRdfLiteralTermSerializer<T>
    implements RdfLiteralTermSerializer<T> {
  final IriTerm _datatype;
  final String Function(T value) _convertToString;

  BaseRdfLiteralTermSerializer({
    required IriTerm datatype,
    String Function(T value)? convertToString,
  }) : _datatype = datatype,
       _convertToString = convertToString ?? ((value) => value.toString());

  @override
  LiteralTerm toLiteralTerm(T value, SerializationContext context) {
    return LiteralTerm(_convertToString(value), datatype: _datatype);
  }
}

class IriIdStringDeserializer extends BaseIriIdDeserializer<String> {
  IriIdStringDeserializer({super.expectedSubjectBaseIri})
    : super(convertFromString: (s) => s);
}

class IriIdIntDeserializer extends BaseIriIdDeserializer<int> {
  IriIdIntDeserializer({super.expectedSubjectBaseIri})
    : super(convertFromString: (s) => int.parse(s));
}

class BaseIriIdDeserializer<T> extends RdfIriTermDeserializer<T> {
  final T Function(String) _convertFromString;
  final String? _expectedSubjectBaseIri;

  BaseIriIdDeserializer({
    required T Function(String) convertFromString,
    String? expectedSubjectBaseIri,
  }) : _convertFromString = convertFromString,
       _expectedSubjectBaseIri = expectedSubjectBaseIri;

  @override
  fromIriTerm(IriTerm term, DeserializationContext context) {
    try {
      final subjectUri = term.iri;
      var idString = subjectUri.split('/').last;
      var subjectBaseIri = subjectUri.substring(
        0,
        subjectUri.length - idString.length,
      );
      if (_expectedSubjectBaseIri != null &&
          _expectedSubjectBaseIri != subjectBaseIri) {
        throw DeserializationException(
          message:
              "Expected Base IRI $_expectedSubjectBaseIri but got $subjectBaseIri",
        );
      }
      return _convertFromString(idString);
    } on DeserializationException {
      rethrow;
    } catch (e) {
      throw DeserializationException(
        message:
            'Failed to parse Iri Id from ${T.toString()}: ${term.iri}. Error: $e',
      );
    }
  }
}

final class IriIdSerializer extends RdfIriTermSerializer<String> {
  final String _baseIri;

  IriIdSerializer({required String baseIri}) : _baseIri = baseIri;

  @override
  toIriTerm(String id, SerializationContext context) {
    assert(!id.contains("/"));
    if (id.contains("/")) {
      throw SerializationException(
        message:
            'Expected an Id, not a full IRI: $id - want to prepend baseIri $_baseIri',
      );
    }
    return IriTerm("$_baseIri/$id");
  }
}

final class IriFullDeserializer extends RdfIriTermDeserializer<String> {
  @override
  fromIriTerm(IriTerm term, DeserializationContext context) {
    return term.iri;
  }
}

final class IriFullSerializer extends RdfIriTermSerializer<String> {
  @override
  toIriTerm(String iri, SerializationContext context) {
    return IriTerm(iri);
  }
}

final class StringDeserializer extends BaseRdfLiteralTermDeserializer<String> {
  StringDeserializer({IriTerm? datatype})
    : super(
        datatype: datatype ?? XsdConstants.stringIri,
        convertFromLiteral: (term, _) => term.value,
      );
}

final class StringSerializer extends BaseRdfLiteralTermSerializer<String> {
  StringSerializer({IriTerm? datatype})
    : super(
        datatype: datatype ?? XsdConstants.stringIri,
        convertToString: (s) => s,
      );
}

final class IntDeserializer extends BaseRdfLiteralTermDeserializer<int> {
  IntDeserializer({IriTerm? datatype})
    : super(
        datatype: datatype ?? XsdConstants.integerIri,
        convertFromLiteral: (term, _) => int.parse(term.value),
      );
}

final class IntSerializer extends BaseRdfLiteralTermSerializer<int> {
  IntSerializer({IriTerm? datatype})
    : super(
        datatype: datatype ?? XsdConstants.integerIri,
        convertToString: (i) => i.toString(),
      );
}

final class DoubleDeserializer extends BaseRdfLiteralTermDeserializer<double> {
  DoubleDeserializer({IriTerm? datatype})
    : super(
        datatype: datatype ?? XsdConstants.decimalIri,
        convertFromLiteral: (term, _) => double.parse(term.value),
      );
}

final class DoubleSerializer extends BaseRdfLiteralTermSerializer<double> {
  DoubleSerializer({IriTerm? datatype})
    : super(
        datatype: datatype ?? XsdConstants.decimalIri,
        convertToString: (d) => d.toString(),
      );
}

final class DateTimeDeserializer
    extends BaseRdfLiteralTermDeserializer<DateTime> {
  DateTimeDeserializer({IriTerm? datatype})
    : super(
        datatype: datatype ?? XsdConstants.dateTimeIri,
        convertFromLiteral: (term, _) => DateTime.parse(term.value).toUtc(),
      );
}

final class DateTimeSerializer extends BaseRdfLiteralTermSerializer<DateTime> {
  DateTimeSerializer({IriTerm? datatype})
    : super(
        datatype: datatype ?? XsdConstants.dateTimeIri,
        convertToString: (dateTime) => dateTime.toUtc().toIso8601String(),
      );
}

final class BoolDeserializer extends BaseRdfLiteralTermDeserializer<bool> {
  BoolDeserializer({IriTerm? datatype})
    : super(
        datatype: datatype ?? XsdConstants.booleanIri,
        convertFromLiteral: (term, _) {
          final value = term.value.toLowerCase();

          if (value == 'true' || value == '1') {
            return true;
          } else if (value == 'false' || value == '0') {
            return false;
          }

          throw DeserializationException(
            message: 'Failed to parse boolean: ${term.value}',
          );
        },
      );
}

final class BoolSerializer extends BaseRdfLiteralTermSerializer<bool> {
  BoolSerializer({IriTerm? datatype})
    : super(
        datatype: datatype ?? XsdConstants.booleanIri,
        convertToString: (b) => b.toString(),
      );
}

class SerializationException extends RdfMappingException {
  SerializationException({super.message});
}

class DeserializationException extends RdfMappingException {
  DeserializationException({super.message});
}

/// Central registry for RDF type mappers
///
/// Provides a way to register and retrieve mappers for specific types.
/// This is the core of the mapping system, managing type-to-mapper associations.
final class RdfMapperRegistry {
  final Map<Type, RdfIriTermDeserializer<dynamic>> _iriDeserializers = {};
  final Map<Type, RdfIriTermSerializer<dynamic>> _iriSerializers = {};
  final Map<Type, RdfBlankNodeTermDeserializer<dynamic>>
  _blankNodeDeserializers = {};
  final Map<Type, RdfBlankNodeTermSerializer<dynamic>> _blankNodeSerializers =
      {};
  final Map<Type, RdfLiteralTermDeserializer<dynamic>> _literalDeserializers =
      {};
  final Map<Type, RdfLiteralTermSerializer<dynamic>> _literalSerializers = {};
  final Map<Type, RdfToTriplesSerializer<dynamic>> _toTriplesSerializers = {};
  final ContextLogger _logger;

  /// Creates a new RDF mapper registry
  ///
  /// @param loggerService Optional logger for diagnostic information
  RdfMapperRegistry({LoggerService? loggerService})
    : _logger = (loggerService ?? LoggerService()).createLogger(
        'RdfMapperRegistry',
      ) {
    // commonly used deserializers
    registerIriDeserializer(IriFullDeserializer());
    registerIriSerializer(IriFullSerializer());

    registerLiteralDeserializer(StringDeserializer());
    registerLiteralDeserializer(IntDeserializer());
    registerLiteralDeserializer(DoubleDeserializer());
    registerLiteralDeserializer(BoolDeserializer());
    registerLiteralDeserializer(DateTimeDeserializer());

    registerLiteralSerializer(StringSerializer());
    registerLiteralSerializer(IntSerializer());
    registerLiteralSerializer(DoubleSerializer());
    registerLiteralSerializer(BoolSerializer());
    registerLiteralSerializer(DateTimeSerializer());
  }

  void registerIriDeserializer<T>(RdfIriTermDeserializer<T> deserializer) {
    _logger.debug('Registering IriTerm deserializer for type ${T.toString()}');
    _iriDeserializers[T] = deserializer;
  }

  void registerIriSerializer<T>(RdfIriTermSerializer<T> serializer) {
    _logger.debug('Registering IriTerm serializer for type ${T.toString()}');
    _iriSerializers[T] = serializer;
  }

  void registerLiteralDeserializer<T>(
    RdfLiteralTermDeserializer<T> deserializer,
  ) {
    _logger.debug(
      'Registering LiteralTerm deserializer for type ${T.toString()}',
    );
    _literalDeserializers[T] = deserializer;
  }

  void registerLiteralSerializer<T>(RdfLiteralTermSerializer<T> serializer) {
    _logger.debug(
      'Registering LiteralTerm serializer for type ${T.toString()}',
    );
    _literalSerializers[T] = serializer;
  }

  void registerBlankNodeDeserializer<T>(
    RdfBlankNodeTermDeserializer<T> deserializer,
  ) {
    _logger.debug(
      'Registering BlankNodeTerm deserializer for type ${T.toString()}',
    );
    _blankNodeDeserializers[T] = deserializer;
  }

  void registerBlankNodeSerializer<T>(
    RdfBlankNodeTermSerializer<T> serializer,
  ) {
    _logger.debug(
      'Registering BlankNodeTerm serializer for type ${T.toString()}',
    );
    _blankNodeSerializers[T] = serializer;
  }

  void registerTriplesSerializer<T>(RdfToTriplesSerializer<T> serializer) {
    _logger.debug(
      'Registering ToTriples deserializer for type ${T.toString()}',
    );
    _toTriplesSerializers[T] = serializer;
  }

  /// Gets the deserializer for a specific type
  ///
  /// @return The deserializer for type T or null if none is registered
  RdfIriTermDeserializer<T> getIriDeserializer<T>() {
    final deserializer = _iriDeserializers[T];
    if (deserializer == null) {
      throw DeserializerNotFoundException('RdfIriTermDeserializer', T);
    }
    return deserializer as RdfIriTermDeserializer<T>;
  }

  RdfIriTermSerializer<T> getIriSerializer<T>() {
    final serializer = _iriSerializers[T];
    if (serializer == null) {
      throw SerializerNotFoundException('RdfIriTermSerializer', T);
    }
    return serializer as RdfIriTermSerializer<T>;
  }

  RdfLiteralTermDeserializer<T> getLiteralDeserializer<T>() {
    final deserializer = _literalDeserializers[T];
    if (deserializer == null) {
      throw DeserializerNotFoundException('RdfLiteralTermDeserializer', T);
    }
    return deserializer as RdfLiteralTermDeserializer<T>;
  }

  RdfLiteralTermSerializer<T> getLiteralSerializer<T>() {
    final serializer = _literalSerializers[T];
    if (serializer == null) {
      throw SerializerNotFoundException('RdfLiteralTermSerializer', T);
    }
    return serializer as RdfLiteralTermSerializer<T>;
  }

  RdfBlankNodeTermDeserializer<T> getBlankNodeDeserializer<T>() {
    final deserializer = _blankNodeDeserializers[T];
    if (deserializer == null) {
      throw DeserializerNotFoundException('RdfBlankNodeTermDeserializer', T);
    }
    return deserializer as RdfBlankNodeTermDeserializer<T>;
  }

  RdfBlankNodeTermSerializer<T> getBlankNodeSerializer<T>() {
    final serializer = _blankNodeSerializers[T];
    if (serializer == null) {
      throw SerializerNotFoundException('RdfBlankNodeTermSerializer', T);
    }
    return serializer as RdfBlankNodeTermSerializer<T>;
  }

  RdfToTriplesSerializer<T> getToTriplesSerializer<T>() {
    final serializer = _toTriplesSerializers[T];
    if (serializer == null) {
      throw SerializerNotFoundException('RdfToTriplesSerializer', T);
    }
    return serializer as RdfToTriplesSerializer<T>;
  }

  /// Checks if a mapper exists for a type
  ///
  /// @return true if a mapper is registered for type T, false otherwise
  bool hasIriDeserializerFor<T>() => _iriDeserializers.containsKey(T);
  bool hasLiteralDeserializerFor<T>() => _literalDeserializers.containsKey(T);
  bool hasBlankNodeDeserializerFor<T>() =>
      _blankNodeDeserializers.containsKey(T);
  bool hasIriSerializerFor<T>() => _iriSerializers.containsKey(T);
  bool hasLiteralSerializerFor<T>() => _literalSerializers.containsKey(T);
  bool hasBlankNodeSerializerFor<T>() => _blankNodeSerializers.containsKey(T);
  bool hasToTriplesSerializerFor<T>() => _toTriplesSerializers.containsKey(T);
}
