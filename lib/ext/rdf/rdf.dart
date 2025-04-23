/// Core RDF library providing parsing, serializing and manipulation of RDF data
///
/// This library provides a unified API for working with RDF data in different formats
/// through a plugin-based architecture that allows custom formats to be registered.
library rdf;

import 'core/graph/rdf_graph.dart';
import 'core/plugin/format_plugin.dart';
import 'core/rdf_parser.dart';
import 'core/rdf_serializer.dart';
import 'jsonld/jsonld_format.dart';
import 'turtle/turtle_format.dart';

export 'core/graph/rdf_graph.dart';
export 'core/graph/rdf_term.dart';
export 'core/graph/triple.dart';
export 'core/plugin/format_plugin.dart';
export 'core/rdf_parser.dart';
export 'core/rdf_serializer.dart';

/// Central facade for the RDF library, providing access to parsing and serialization.
///
/// This class provides convenient methods for parsing and serializing RDF data
/// without manually creating factories. It follows IoC principles by accepting
/// dependencies in its constructor.
final class RdfLibrary {
  final RdfFormatRegistry _registry;
  final RdfParserFactory _parserFactory;
  final RdfSerializerFactory _serializerFactory;

  /// Creates a new RDF library instance with the given registry and factories
  ///
  /// This constructor allows for full dependency injection, enabling testing
  /// and customization of the library's components.
  RdfLibrary({
    required RdfFormatRegistry registry,
    required RdfParserFactory parserFactory,
    required RdfSerializerFactory serializerFactory,
  }) : _registry = registry,
       _parserFactory = parserFactory,
       _serializerFactory = serializerFactory;

  /// Creates a new RDF library instance with standard formats registered
  ///
  /// This convenience constructor automatically sets up a registry with the default
  /// formats (Turtle and JSON-LD) for immediate use.
  factory RdfLibrary.withStandardFormats() {
    final registry = RdfFormatRegistry();

    // Register standard formats
    registry.registerFormat(const TurtleFormat());
    registry.registerFormat(const JsonLdFormat());

    final parserFactory = RdfParserFactory(registry);
    final serializerFactory = RdfSerializerFactory(registry);

    return RdfLibrary(
      registry: registry,
      parserFactory: parserFactory,
      serializerFactory: serializerFactory,
    );
  }

  /// Parse RDF content to create a graph
  ///
  /// [content] The RDF content to parse
  /// [contentType] Optional MIME type to specify the format (auto-detected if not provided)
  /// [documentUrl] Optional base URI for resolving relative references
  RdfGraph parse(String content, {String? contentType, String? documentUrl}) {
    return _parserFactory.parse(
      content,
      contentType: contentType,
      documentUrl: documentUrl,
    );
  }

  /// Serialize an RDF graph to a string representation
  ///
  /// [graph] The RDF graph to serialize
  /// [contentType] Optional MIME type to specify the output format (uses default if not provided)
  /// [baseUri] Optional base URI for the serialized output
  /// [customPrefixes] Optional custom namespace prefix mappings
  ///
  /// @throws FormatNotSupportedException if the requested format is not supported
  String serialize(
    RdfGraph graph, {
    String? contentType,
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) {
    return _serializerFactory.write(
      graph,
      contentType: contentType,
      baseUri: baseUri,
      customPrefixes: customPrefixes,
    );
  }

  /// Register a custom format with the RDF library
  ///
  /// [format] The format implementation to register
  ///
  /// This allows adding support for additional serialization formats beyond
  /// the standard ones provided by the library.
  void registerFormat(RdfFormat format) {
    _registry.registerFormat(format);
  }

  /// Get an instance of a parser for a specific format
  ///
  /// [contentType] MIME type of the format to get a parser for
  RdfParser getParser({String? contentType}) {
    return _parserFactory.createParser(contentType: contentType);
  }

  /// Get an instance of a serializer for a specific format
  ///
  /// [contentType] MIME type of the format to get a serializer for
  RdfSerializer getSerializer({String? contentType}) {
    return _serializerFactory.createSerializer(contentType: contentType);
  }

  /// Access to the underlying format registry
  RdfFormatRegistry get registry => _registry;
}
