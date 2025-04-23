/// Library defining serialization-specific exceptions
library ext.rdf.core.exceptions.serializer;

import 'rdf_exception.dart';

/// Base exception class for all RDF serialization-related errors
class RdfSerializerException extends RdfException {
  /// Format being serialized to when the exception occurred
  final String format;

  /// Creates a new RDF serializer exception
  const RdfSerializerException(
    super.message, {
    required this.format,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfSerializerException($format): $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}

/// Exception thrown when the serializer encounters an unsupported feature
class RdfUnsupportedSerializationFeatureException
    extends RdfSerializerException {
  /// Feature that is not supported
  final String feature;

  /// Creates a new unsupported serialization feature exception
  const RdfUnsupportedSerializationFeatureException(
    super.message, {
    required this.feature,
    required super.format,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfUnsupportedSerializationFeatureException($format): $feature - $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}
