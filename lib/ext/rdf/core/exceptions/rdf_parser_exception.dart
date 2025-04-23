/// Library defining parser-specific exceptions
library ext.rdf.core.exceptions.parser;

import 'rdf_exception.dart';

/// Base exception class for all RDF parser-related errors
class RdfParserException extends RdfException {
  /// Format being parsed when the exception occurred
  final String format;

  /// Creates a new RDF parser exception
  const RdfParserException(
    super.message, {
    required this.format,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfParserException($format): $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}

/// Exception thrown when the parser encounters syntax errors in the input
class RdfSyntaxException extends RdfParserException {
  /// Creates a new RDF syntax exception
  const RdfSyntaxException(
    super.message, {
    required super.format,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfSyntaxException($format): $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}

/// Exception thrown when the parser encounters an unsupported feature
class RdfUnsupportedFeatureException extends RdfParserException {
  /// Feature that is not supported
  final String feature;

  /// Creates a new unsupported feature exception
  const RdfUnsupportedFeatureException(
    super.message, {
    required this.feature,
    required super.format,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfUnsupportedFeatureException($format): $feature - $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}

/// Exception thrown when the parser encounters an invalid IRI
class RdfInvalidIriException extends RdfParserException {
  /// The invalid IRI
  final String iri;

  /// Creates a new invalid IRI exception
  const RdfInvalidIriException(
    super.message, {
    required this.iri,
    required super.format,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfInvalidIriException($format): Invalid IRI "$iri" - $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}
