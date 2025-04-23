import 'graph/rdf_graph.dart';
import 'plugin/format_plugin.dart';

/// Interface for writing RDF graphs to different serialization formats.
///
/// This interface provides a strategy pattern implementation for serializing
/// RDF graphs to various formats (Turtle, JSON-LD, etc.) based on content type.
abstract interface class RdfSerializer {
  /// Serializes an RDF graph to a string representation in a specific format.
  ///
  /// [graph] The RDF graph to serialize.
  /// [baseUri] Optional base URI for resolving relative IRIs in the output.
  /// [customPrefixes] Optional map of prefix to namespace mappings to use in serialization.
  /// Returns the serialized representation as a string.
  String write(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  });
}

/// Interface for serializer factories that create RDF serializer instances
abstract interface class RdfSerializerFactoryBase {
  /// Creates an RdfSerializer for the specified content type.
  ///
  /// [contentType] MIME type that determines which serializer to use.
  /// If null, uses the default serializer (typically Turtle).
  ///
  /// @throws FormatNotSupportedException if no serializer is available for the content type
  RdfSerializer createSerializer({String? contentType});

  /// Directly serialize an RDF graph to the specified format
  ///
  /// Convenience method that creates a serializer and uses it to serialize the graph.
  ///
  /// @throws FormatNotSupportedException if no serializer is available for the content type
  String write(
    RdfGraph graph, {
    String? contentType,
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  });
}

/// Factory for creating RDF serializers based on content type.
///
/// This class follows the Factory pattern to create appropriate RdfSerializer
/// implementations based on the requested content type.
final class RdfSerializerFactory implements RdfSerializerFactoryBase {
  final RdfFormatRegistry _registry;

  /// Creates a new serializer factory using the specified registry
  RdfSerializerFactory(this._registry);

  @override
  RdfSerializer createSerializer({String? contentType}) {
    return _registry.getSerializer(contentType);
  }

  @override
  String write(
    RdfGraph graph, {
    String? contentType,
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) {
    final serializer = createSerializer(contentType: contentType);
    return serializer.write(
      graph,
      baseUri: baseUri,
      customPrefixes: customPrefixes,
    );
  }
}
