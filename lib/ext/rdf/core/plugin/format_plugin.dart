import 'package:logging/logging.dart';

import '../graph/rdf_graph.dart';
import '../rdf_parser.dart';
import '../rdf_serializer.dart';

/// Represents a content format that can be handled by the RDF framework.
///
/// A content format is identified by one or more MIME types and provides
/// functionality for both parsing and serialization.
abstract interface class RdfFormat {
  /// The primary MIME type for this format
  String get primaryMimeType;

  /// All MIME types supported by this format
  Set<String> get supportedMimeTypes;

  /// Creates a parser instance for this format
  RdfParser createParser();

  /// Creates a serializer instance for this format
  RdfSerializer createSerializer();

  /// Tests if the provided content is likely in this format
  ///
  /// Used for format detection when no explicit MIME type is available
  bool canParse(String content);
}

/// Manages registration and discovery of RDF format plugins.
///
/// This registry acts as the central point for format plugin management, providing
/// a mechanism for plugin discovery and access.
final class RdfFormatRegistry {
  final _logger = Logger('rdf.format_registry');
  final Map<String, RdfFormat> _formatsByMimeType = {};
  final List<RdfFormat> _formats = [];

  /// Creates a new format registry
  RdfFormatRegistry();

  /// Register a new format with the registry
  ///
  /// This will make the format available for parsing and serialization
  /// when requested by any of its supported MIME types.
  void registerFormat(RdfFormat format) {
    _logger.fine('Registering format: ${format.primaryMimeType}');
    _formats.add(format);

    for (final mimeType in format.supportedMimeTypes) {
      final normalized = _normalizeMimeType(mimeType);
      _formatsByMimeType[normalized] = format;
    }
  }

  /// Retrieves a format instance by MIME type
  ///
  /// Returns null if no format is registered for the provided MIME type
  RdfFormat? getFormat(String? mimeType) {
    if (mimeType == null) return null;
    return _formatsByMimeType[_normalizeMimeType(mimeType)];
  }

  /// Retrieves all registered formats
  List<RdfFormat> getAllFormats() => List.unmodifiable(_formats);

  /// Detect format from content when no MIME type is available
  ///
  /// Attempts to identify the format by examining the content structure.
  /// Returns the first format that claims it can parse the content.
  RdfFormat? detectFormat(String content) {
    _logger.fine('Attempting to detect format from content');

    for (final format in _formats) {
      if (format.canParse(content)) {
        _logger.fine('Detected format: ${format.primaryMimeType}');
        return format;
      }
    }

    _logger.fine('No format detected');
    return null;
  }

  /// Get a parser for a specific MIME type
  ///
  /// If no MIME type is provided or no matching format is found,
  /// returns a format-detecting parser that tries to determine the format
  /// from content.
  RdfParser getParser(String? mimeType) {
    final format = getFormat(mimeType);
    if (format != null) {
      return format.createParser();
    }

    // No specific format found, return a detecting parser
    return FormatDetectingParser(this);
  }

  /// Get a serializer for a specific MIME type
  ///
  /// If no matching format is found, throws FormatNotSupportedException.
  /// If no MIME type is provided, returns the default serializer (Turtle).
  RdfSerializer getSerializer(String? mimeType) {
    if (mimeType == null) {
      // Use the first registered format as default
      if (_formats.isNotEmpty) {
        return _formats.first.createSerializer();
      }
      throw FormatNotSupportedException('No formats registered');
    }

    final format = getFormat(mimeType);
    if (format == null) {
      throw FormatNotSupportedException(
        'No serializer available for MIME type: $mimeType',
      );
    }

    return format.createSerializer();
  }

  /// Helper method to normalize MIME types for consistent lookup
  static String _normalizeMimeType(String mimeType) {
    return mimeType.trim().toLowerCase();
  }

  /// Clear all registered formats (mainly for testing)
  void clear() {
    _formats.clear();
    _formatsByMimeType.clear();
  }
}

/// Thrown when an attempt is made to serialize to an unsupported format
class FormatNotSupportedException implements Exception {
  final String message;

  FormatNotSupportedException(this.message);

  @override
  String toString() => 'FormatNotSupportedException: $message';
}

/// A parser that detects the format from content and delegates to the appropriate parser
final class FormatDetectingParser implements RdfParser {
  final _logger = Logger('rdf.format_detecting_parser');
  final RdfFormatRegistry _registry;

  FormatDetectingParser(this._registry);

  @override
  RdfGraph parse(String input, {String? documentUrl}) {
    final format = _registry.detectFormat(input);

    if (format != null) {
      _logger.fine('Using detected format: ${format.primaryMimeType}');
      return format.createParser().parse(input, documentUrl: documentUrl);
    }

    // If we can't detect, try the first available format
    final formats = _registry.getAllFormats();
    if (formats.isEmpty) {
      throw FormatNotSupportedException('No RDF formats registered');
    }

    // Try each format in sequence until one works
    Exception? lastException;
    for (final format in formats) {
      try {
        _logger.fine('Trying format: ${format.primaryMimeType}');
        return format.createParser().parse(input, documentUrl: documentUrl);
      } catch (e) {
        _logger.fine('Failed with format ${format.primaryMimeType}: $e');
        lastException = e is Exception ? e : Exception(e.toString());
      }
    }

    throw FormatNotSupportedException(
      'Could not parse content with any registered format: ${lastException?.toString() ?? "unknown error"}',
    );
  }
}
