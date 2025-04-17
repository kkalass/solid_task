import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/mapping/rdf_mapper_registry.dart';

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

  /// Common prefixes for RDF serialization
  // FIXME KK: does this really belong here?
  final Map<String, String> _commonPrefixes = {
    'rdf': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    'dcterms': 'http://purl.org/dc/terms/',
    'xsd': 'http://www.w3.org/2001/XMLSchema#',
    'task': 'http://solidtask.org/ontology#',
  };

  /// Creates a new RDF mapper service
  RdfMapperService({
    required RdfMapperRegistry registry,
    LoggerService? loggerService,
    RdfSerializer? serializer,
    RdfSerializerFactory? serializerFactory,
    RdfParser? parser,
    RdfParserFactory? parserFactory,
    String contentType = 'text/turtle',
  }) : _registry = registry,
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
               .createParser(contentType: contentType);

  /// Access to the registry for registering custom mappers
  RdfMapperRegistry get registry => _registry;

  T fromTriples<T>(
    String storageRoot,
    List<Triple> triples,
    RdfSubject rdfSubject, {
    RdfIriTermDeserializer<T>? iriDeserializer,
    RdfBlankNodeTermDeserializer<T>? blankNodeDeserializer,
  }) {
    return fromGraph(
      storageRoot,
      RdfGraph(triples: triples),
      rdfSubject,
      iriDeserializer: iriDeserializer,
      blankNodeDeserializer: blankNodeDeserializer,
    );
  }

  T fromGraph<T>(
    String storageRoot,
    RdfGraph graph,
    RdfSubject rdfSubject, {
    RdfIriTermDeserializer<T>? iriDeserializer,
    RdfBlankNodeTermDeserializer<T>? blankNodeDeserializer,
  }) {
    _logger.debug('Delegated mapping graph to ${T.toString()}');

    var context = DeserializationContextImpl(
      storageRoot: storageRoot,
      graph: graph,
      registry: _registry,
    );

    return context.fromRdf(
      rdfSubject,
      iriDeserializer,
      null,
      blankNodeDeserializer,
    );
  }

  /// Map an object to RDF graph
  ///
  /// Converts a domain object to an RDF graph using the registered mapper
  ///
  /// @param instance The object to convert
  /// @param uri Optional URI to use as the subject
  /// @return RDF graph representing the object
  /// @throws StateError if no mapper is registered for type T
  RdfGraph toGraph<T>(
    String storageRoot,
    T instance, {
    String? uri,
    RdfSubjectSerializer? serializer,
  }) {
    _logger.debug('Converting instance of ${T.toString()} to RDF graph');

    final context = SerializationContextImpl(
      storageRoot: storageRoot,
      registry: _registry,
    );

    var (_, triples) = context.subject(instance, serializer: serializer);

    return RdfGraph(triples: triples);
  }

  /// Serialize object to RDF string
  ///
  /// Converts a domain object to a serialized RDF string
  ///
  /// @param instance The object to serialize
  /// @param uri Optional URI to use as the subject
  /// @return Serialized RDF string
  String asString<T>(
    String storageRoot,
    T instance, {
    String? uri,
    RdfSubjectSerializer? serializer,
  }) {
    _logger.debug('Serializing instance of ${T.toString()} to RDF string');

    final graph = toGraph<T>(
      storageRoot,
      instance,
      uri: uri,
      serializer: serializer,
    );
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
  T fromString<T>(
    String storageRoot,
    String rdfString,
    String uri, {
    String? documentUrl,
    RdfIriTermDeserializer<T>? iriDeserializer,
    RdfBlankNodeTermDeserializer<T>? blankNodeDeserializer,
  }) {
    _logger.debug('Deserializing RDF string to ${T.toString()}');

    final graph = _parser.parse(rdfString, documentUrl: documentUrl);
    return fromGraph<T>(
      storageRoot,
      graph,
      IriTerm(uri),
      iriDeserializer: iriDeserializer,
      blankNodeDeserializer: blankNodeDeserializer,
    );
  }
}
