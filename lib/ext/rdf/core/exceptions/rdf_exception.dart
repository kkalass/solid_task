/// Library defining exceptions for RDF operations
library ext.rdf.core.exceptions;

/// Base exception class for all RDF-related errors.
///
/// This serves as the parent class for all specific exceptions
/// that can occur during RDF operations.
class RdfException implements Exception {
  /// Human-readable error message
  final String message;

  /// The original error that caused this exception, if any
  final Object? cause;

  /// Optional source information where the error occurred
  final SourceLocation? source;

  /// Creates a new RDF exception
  const RdfException(this.message, {this.cause, this.source});

  @override
  String toString() {
    final buffer = StringBuffer('RdfException: $message');

    if (source != null) {
      buffer.write(' at ${source!}');
    }

    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }

    return buffer.toString();
  }
}

/// Contains information about source location where an error occurred
class SourceLocation {
  /// Line number (0-based) in the source where the error was detected
  final int line;

  /// Column number (0-based) in the source where the error was detected
  final int column;

  /// Optional file path or URL where the error occurred
  final String? source;

  /// Optional context showing the problematic content
  final String? context;

  /// Creates a new source location instance
  const SourceLocation({
    required this.line,
    required this.column,
    this.source,
    this.context,
  });

  @override
  String toString() {
    final location = source != null ? '$source:' : '';
    return '$location${line + 1}:${column + 1}${context != null ? ' "$context"' : ''}';
  }
}
