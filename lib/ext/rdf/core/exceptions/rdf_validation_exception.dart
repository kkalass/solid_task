/// Library defining validation-specific exceptions
library ext.rdf.core.exceptions.validation;

import 'rdf_exception.dart';

/// Base exception class for all RDF validation-related errors
class RdfValidationException extends RdfException {
  /// Creates a new RDF validation exception
  const RdfValidationException(super.message, {super.cause, super.source});

  @override
  String toString() {
    return 'RdfValidationException: $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}

/// Exception thrown when an RDF model constraint is violated
class RdfConstraintViolationException extends RdfValidationException {
  /// The name of the violated constraint
  final String constraint;

  /// Creates a new constraint violation exception
  const RdfConstraintViolationException(
    super.message, {
    required this.constraint,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    return 'RdfConstraintViolationException: $constraint - $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}

/// Exception thrown when there's a type error in RDF data
class RdfTypeException extends RdfValidationException {
  /// Expected type
  final String expectedType;

  /// Actual type found
  final String? actualType;

  /// Creates a new RDF type exception
  const RdfTypeException(
    super.message, {
    required this.expectedType,
    this.actualType,
    super.cause,
    super.source,
  });

  @override
  String toString() {
    final typeInfo =
        actualType != null
            ? 'Expected: $expectedType, Found: $actualType'
            : 'Expected: $expectedType';
    return 'RdfTypeException: $typeInfo - $message${source != null ? ' at $source' : ''}${cause != null ? '\nCaused by: $cause' : ''}';
  }
}
