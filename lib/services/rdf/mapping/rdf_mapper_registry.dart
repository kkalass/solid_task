import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';

/// Core interface for RDF type mappers
///
/// Defines the contract for converting between domain objects and RDF triples.
/// Each type requiring RDF serialization should have an implementation of this interface.
abstract interface class RdfTypeMapper<T> {
  /// Maps an object to RDF triples
  ///
  /// Converts a domain object to a set of RDF triples
  ///
  /// @param instance The object to convert
  /// @param subjectUri The URI to use as the subject for the main resource
  /// @return List of RDF triples representing the object
  List<Triple> toTriples(T instance, String subjectUri);

  /// Maps RDF triples back to an object
  ///
  /// Reconstructs a domain object from RDF triples
  ///
  /// @param triples The triples containing the object data
  /// @param subjectUri The URI of the main resource
  /// @return A reconstructed domain object
  T fromTriples(List<Triple> triples, String subjectUri);

  /// Creates a new instance (used during deserialization)
  ///
  /// @return A new empty instance of the mapped type
  T createInstance();

  /// Generates a URI for an instance based on its identity
  ///
  /// @param instance The object to generate a URI for
  /// @param baseUri Optional base URI to prepend
  /// @return A URI string that uniquely identifies the object
  String generateUri(T instance, {String? baseUri});
}

/// Central registry for RDF type mappers
///
/// Provides a way to register and retrieve mappers for specific types.
/// This is the core of the mapping system, managing type-to-mapper associations.
final class RdfMapperRegistry {
  final Map<Type, RdfTypeMapper<dynamic>> _mappers = {};
  final ContextLogger _logger;

  /// Creates a new RDF mapper registry
  ///
  /// @param loggerService Optional logger for diagnostic information
  RdfMapperRegistry({LoggerService? loggerService})
    : _logger = (loggerService ?? LoggerService()).createLogger(
        'RdfMapperRegistry',
      );

  /// Registers a mapper for a specific type
  ///
  /// @param mapper The mapper implementation to register
  void registerMapper<T>(RdfTypeMapper<T> mapper) {
    _logger.debug('Registering mapper for type ${T.toString()}');
    _mappers[T] = mapper;
  }

  /// Gets the mapper for a specific type
  ///
  /// @return The mapper for type T or null if none is registered
  RdfTypeMapper<T>? getMapper<T>() {
    final mapper = _mappers[T];
    if (mapper == null) {
      _logger.warning('No mapper registered for type ${T.toString()}');
      return null;
    }
    return mapper as RdfTypeMapper<T>;
  }

  /// Gets a mapper based on runtime type
  ///
  /// Useful when dealing with dynamic objects where compile-time type is not known
  ///
  /// @param instance The object to get a mapper for
  /// @return The mapper for the runtime type of instance or null if none is registered
  RdfTypeMapper<T>? getMapperForInstance<T>(T instance) {
    final type = instance.runtimeType;
    final mapper = _mappers[type];
    if (mapper == null) {
      _logger.warning(
        'No mapper registered for runtime type ${type.toString()}',
      );
      return null;
    }
    return mapper as RdfTypeMapper<T>;
  }

  /// Checks if a mapper exists for a type
  ///
  /// @return true if a mapper is registered for type T, false otherwise
  bool hasMapperFor<T>() => _mappers.containsKey(T);
}
