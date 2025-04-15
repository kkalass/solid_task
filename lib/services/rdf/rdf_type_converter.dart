import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';

/// Converts between Dart types and RDF literals
///
/// This class is responsible for converting between Dart primitive types
/// and their corresponding RDF literal representations.
class RdfTypeConverter {
  final ContextLogger? _logger;

  /// Creates a new RdfTypeConverter
  ///
  /// [loggerService] Optional logger for diagnostic information
  RdfTypeConverter({LoggerService? loggerService})
    : _logger = loggerService?.createLogger('RdfTypeConverter');

  /// Creates a string literal term
  LiteralTerm createStringLiteral(String value) {
    return LiteralTerm.string(value);
  }

  /// Creates a boolean literal with XSD boolean datatype
  LiteralTerm createBooleanLiteral(bool value) {
    return LiteralTerm.typed(value.toString(), 'boolean');
  }

  /// Creates a dateTime literal with XSD dateTime datatype
  LiteralTerm createDateTimeLiteral(DateTime dateTime) {
    final utcDateTime = dateTime.toUtc();
    final isoString = utcDateTime.toIso8601String();
    return LiteralTerm.typed(isoString, 'dateTime');
  }

  /// Creates an integer literal with XSD integer datatype
  LiteralTerm createIntegerLiteral(int value) {
    return LiteralTerm.typed(value.toString(), 'integer');
  }

  /// Attempts to parse a boolean from an RDF literal
  ///
  /// Returns null if the literal cannot be parsed as boolean
  bool? parseBoolean(LiteralTerm literal) {
    try {
      final value = literal.value.toLowerCase();
      if (value == 'true' || value == 'false') {
        return value == 'true';
      }
      return null;
    } catch (e) {
      _logger?.warning('Failed to parse boolean: ${literal.value}. Error: $e');
      return null;
    }
  }

  /// Attempts to parse a DateTime from an RDF literal
  ///
  /// Returns null if the literal cannot be parsed as DateTime
  DateTime? parseDateTime(LiteralTerm literal) {
    try {
      return DateTime.parse(literal.value).toUtc();
    } catch (e) {
      _logger?.warning('Failed to parse date: ${literal.value}. Error: $e');
      return null;
    }
  }

  /// Attempts to parse an integer from an RDF literal
  ///
  /// Returns null if the literal cannot be parsed as integer
  int? parseInteger(LiteralTerm literal) {
    try {
      return int.parse(literal.value);
    } catch (e) {
      _logger?.warning('Failed to parse integer: ${literal.value}. Error: $e');
      return null;
    }
  }
}
