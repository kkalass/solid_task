import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/mapping/rdf_mapper_registry.dart';
import 'package:solid_task/services/rdf/mapping/rdf_type_converter.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:solid_task/services/rdf/rdf_parser.dart';
import 'package:solid_task/services/rdf/rdf_serializer.dart';

/// Service for converting objects to/from RDF
///
/// This service handles the complete workflow of serializing/deserializing
/// domain objects to/from RDF, using the registered mappers.
final class RdfMapperService {
  final RdfMapperRegistry _registry;
  final ContextLogger _logger;
  final RdfSerializer _serializer;
  final RdfParser _parser;
  final RdfTypeConverter _typeConverter;

  /// Common prefixes for RDF serialization
  final Map<String, String> _commonPrefixes = {
    'rdf': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    'dcterms': 'http://purl.org/dc/terms/',
    'xsd': 'http://www.w3.org/2001/XMLSchema#',
    'task': 'http://solidtask.org/ontology#',
  };

  /// Creates a new RDF mapper service
  RdfMapperService({
    RdfMapperRegistry? registry,
    LoggerService? loggerService,
    RdfSerializer? serializer,
    RdfSerializerFactory? serializerFactory,
    RdfParser? parser,
    RdfParserFactory? parserFactory,
    RdfTypeConverter? typeConverter,
    String contentType = 'text/turtle',
  }) : _registry = registry ?? RdfMapperRegistry(loggerService: loggerService),
       _logger = (loggerService ?? LoggerService()).createLogger(
         'RdfMapperService',
       ),
       _serializer =
           serializer ??
           (serializerFactory ??
                   RdfSerializerFactory(loggerService: loggerService))
               .createSerializer(contentType: contentType),
       _parser =
           parser ??
           (parserFactory ?? RdfParserFactory(loggerService: loggerService))
               .createParser(contentType: contentType),
       _typeConverter =
           typeConverter ?? RdfTypeConverter(loggerService: loggerService);

  /// Access to the registry for registering custom mappers
  RdfMapperRegistry get registry => _registry;

  /// Access to the type converter for basic type conversions
  RdfTypeConverter get typeConverter => _typeConverter;

  /// Map an object to RDF graph
  ///
  /// Converts a domain object to an RDF graph using the registered mapper
  ///
  /// @param instance The object to convert
  /// @param uri Optional URI to use as the subject
  /// @return RDF graph representing the object
  /// @throws StateError if no mapper is registered for type T
  RdfGraph toGraph<T>(T instance, {String? uri}) {
    _logger.debug('Converting instance of ${T.toString()} to RDF graph');

    final mapper = _registry.getMapperForInstance<T>(instance);
    if (mapper == null) {
      throw StateError('No mapper registered for type ${instance.runtimeType}');
    }

    final subjectUri = uri ?? mapper.generateUri(instance);
    final triples = mapper.toTriples(instance, subjectUri);

    return RdfGraph(triples: triples);
  }

  /// Map RDF graph to object
  ///
  /// Reconstructs a domain object from an RDF graph using the registered mapper
  ///
  /// @param graph The RDF graph containing the object data
  /// @param uri The URI of the main resource
  /// @return The reconstructed domain object
  /// @throws StateError if no mapper is registered for type T
  T fromGraph<T>(RdfGraph graph, String uri) {
    _logger.debug('Converting RDF graph to ${T.toString()}');

    final mapper = _registry.getMapper<T>();
    if (mapper == null) {
      throw StateError('No mapper registered for type $T');
    }

    return mapper.fromTriples(graph.triples, uri);
  }

  /// Serialize object to RDF string
  ///
  /// Converts a domain object to a serialized RDF string
  ///
  /// @param instance The object to serialize
  /// @param uri Optional URI to use as the subject
  /// @return Serialized RDF string
  String asString<T>(T instance, {String? uri}) {
    _logger.debug('Serializing instance of ${T.toString()} to RDF string');

    final graph = toGraph<T>(instance, uri: uri);
    return _serializer.write(graph, prefixes: _commonPrefixes);
  }

  /// Deserialize RDF string to object
  ///
  /// Reconstructs a domain object from a serialized RDF string
  ///
  /// @param rdfString The serialized RDF string
  /// @param uri The URI of the main resource
  /// @param parser Optional custom parser to use
  /// @return The reconstructed domain object
  T fromString<T>(String rdfString, String uri, {String? documentUrl}) {
    _logger.debug('Deserializing RDF string to ${T.toString()}');

    final graph = _parser.parse(rdfString, documentUrl: documentUrl);
    return fromGraph<T>(graph, uri);
  }

  // FIXME KK - Code Smell
  /// Update prefixes for serialization
  ///
  /// Adds or replaces prefixes used in serialization
  ///
  /// @param prefixes Map of prefix to namespace URI pairs
  void updatePrefixes(Map<String, String> prefixes) {
    _commonPrefixes.addAll(prefixes);
  }
}
