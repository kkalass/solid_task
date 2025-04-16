import 'package:solid_task/ext/rdf/turtle/turtle_serializer.dart';

import 'graph/rdf_graph.dart';

/// Interface for writing RDF graphs to different serialization formats.
///
/// This interface provides a strategy pattern implementation for serializing
/// RDF graphs to various formats (Turtle, JSON-LD, etc.) based on content type.
abstract class RdfSerializer {
  /// Serializes an RDF graph to a string representation in a specific format.
  ///
  /// [graph] The RDF graph to serialize.
  /// [baseUri] Optional base URI for resolving relative IRIs in the output.
  /// Returns the serialized representation as a string.
  String write(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  });
}

/// Factory for creating RDF serializers based on content type.
///
/// This class follows the Factory pattern to create appropriate RdfSerializer
/// implementations based on the requested content type.
class RdfSerializerFactory {
  /// Creates an RdfSerializer for the specified content type.
  ///
  /// [contentType] MIME type that determines which serializser to use.
  /// If no specific serializzer is found for the content type, falls back to Turtle.
  RdfSerializer createSerializer({String? contentType}) {
    if (contentType == null) {
      // Default to Turtle if no content type specified
      return _getTurtleSerializer();
    }

    // Handle different content types
    final normalizedType = contentType.toLowerCase();

    if (normalizedType.contains('text/turtle')) {
      return _getTurtleSerializer();
    } else if (normalizedType.contains('application/ld+json')) {
      // Future implementation for JSON-LD
      throw UnimplementedError('JSON-LD serializer not implemented yet');
    }

    // Default to Turtle for unrecognized content types
    return _getTurtleSerializer();
  }

  /// Creates a TurtleSerializer instance.
  RdfSerializer _getTurtleSerializer() {
    return TurtleSerializer();
  }
}
