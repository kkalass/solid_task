import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/rdf_constants.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';

/// Type conversion utilities for RDF data
///
/// Handles conversion between Dart types and RDF literals.
/// This class abstracts away the details of RDF datatype handling.
final class RdfTypeConverter {
  final ContextLogger _logger;

  /// Creates a new RDF type converter
  ///
  /// @param loggerService Optional logger for diagnostic information
  RdfTypeConverter({LoggerService? loggerService})
    : _logger = (loggerService ?? LoggerService()).createLogger(
        'RdfTypeConverter',
      );

  /// Creates a string literal term
  ///
  /// @param value The string value to convert
  /// @return An RDF literal with xsd:string datatype
  LiteralTerm createStringLiteral(String value) {
    return LiteralTerm.string(value);
  }

  /// Creates a boolean literal term
  ///
  /// @param value The boolean value to convert
  /// @return An RDF literal with xsd:boolean datatype
  LiteralTerm createBooleanLiteral(bool value) {
    return LiteralTerm(value.toString(), datatype: XsdConstants.booleanIri);
  }

  /// Creates an integer literal term
  ///
  /// @param value The integer value to convert
  /// @return An RDF literal with xsd:integer datatype
  LiteralTerm createIntegerLiteral(int value) {
    return LiteralTerm(value.toString(), datatype: XsdConstants.integerIri);
  }

  /// Creates a dateTime literal term
  ///
  /// @param value The DateTime value to convert
  /// @return An RDF literal with xsd:dateTime datatype
  LiteralTerm createDateTimeLiteral(DateTime dateTime) {
    final utcDateTime = dateTime.toUtc();
    final isoString = utcDateTime.toIso8601String();
    return LiteralTerm(isoString, datatype: XsdConstants.dateTimeIri);
  }

  /// Creates a decimal literal term
  ///
  /// @param value The double value to convert
  /// @return An RDF literal with xsd:decimal datatype
  LiteralTerm createDecimalLiteral(double value) {
    return LiteralTerm(value.toString(), datatype: XsdConstants.decimalIri);
  }

  /// Parses a boolean from an RDF literal
  ///
  /// @param term The literal term to parse
  /// @return The parsed boolean value or null if parsing fails
  bool? parseBoolean(LiteralTerm term) {
    final value = term.value.toLowerCase();

    if (value == 'true' || value == '1') {
      return true;
    } else if (value == 'false' || value == '0') {
      return false;
    }

    _logger.warning('Failed to parse boolean: ${term.value}');
    return null;
  }

  /// Parses an integer from an RDF literal
  ///
  /// @param term The literal term to parse
  /// @return The parsed integer value or null if parsing fails
  int? parseInteger(LiteralTerm term) {
    try {
      return int.parse(term.value);
    } catch (e) {
      _logger.warning('Failed to parse integer: ${term.value}. Error: $e');
      return null;
    }
  }

  /// Parses a double from an RDF literal
  ///
  /// @param term The literal term to parse
  /// @return The parsed double value or null if parsing fails
  double? parseDecimal(LiteralTerm term) {
    try {
      return double.parse(term.value);
    } catch (e) {
      _logger.warning('Failed to parse decimal: ${term.value}. Error: $e');
      return null;
    }
  }

  /// Parses a DateTime from an RDF literal
  ///
  /// @param term The literal term to parse
  /// @return The parsed DateTime value or null if parsing fails
  DateTime? parseDateTime(LiteralTerm term) {
    try {
      return DateTime.parse(term.value).toUtc();
    } catch (e) {
      _logger.warning('Failed to parse date: ${term.value}. Error: $e');
      return null;
    }
  }
}
