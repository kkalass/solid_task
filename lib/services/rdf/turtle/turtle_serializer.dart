import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/rdf_constants.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:solid_task/services/rdf/rdf_serializer.dart';

/// Visitor for converting RDF terms to Turtle syntax string representation
class RdfTermTurtleStringVisitor implements RdfTermVisitor<String> {
  final Map<String, String> _prefixesByIri;

  RdfTermTurtleStringVisitor({required Map<String, String> prefixesByIri})
    : _prefixesByIri = prefixesByIri;

  @override
  String visitIri(IriTerm term) {
    if (term == RdfConstants.typeIri) {
      return 'a';
    } else {
      // Check if the predicate is a known prefix
      final String baseIri;
      final String localPart;

      final iri = term.iri;
      final hashIndex = iri.lastIndexOf('#');
      final slashIndex = iri.lastIndexOf('/');

      if (hashIndex > slashIndex && hashIndex != -1) {
        baseIri = iri.substring(0, hashIndex + 1);
        localPart = iri.substring(hashIndex + 1);
      } else if (slashIndex != -1) {
        baseIri = iri.substring(0, slashIndex + 1);
        localPart = iri.substring(slashIndex + 1);
      } else {
        baseIri = iri;
        localPart = '';
      }
      final prefix = _prefixesByIri[baseIri];
      if (prefix != null) {
        return '$prefix:$localPart';
      } else {
        final prefix = _prefixesByIri[iri];
        if (prefix != null) {
          return '$prefix:';
        }
      }
    }
    return '<${term.iri}>';
  }

  @override
  String visitBlankNode(BlankNodeTerm blankNode) => '_:${blankNode.label}';

  @override
  String visitLiteral(LiteralTerm literal) {
    var escapedLiteralValue = _escapeTurtleString(literal.value);

    if (literal.language != null) {
      return '"$escapedLiteralValue"@${literal.language}';
    } else if (literal.datatype != RdfConstants.stringIri) {
      return '"$escapedLiteralValue"^^${visitIri(literal.datatype)}';
    } else {
      return '"$escapedLiteralValue"';
    }
  }

  /// Escapes a string according to Turtle syntax rules
  ///
  /// Handles standard escape sequences (\n, \r, \t, etc.) and
  /// escapes Unicode characters outside the ASCII range as \uXXXX or \UXXXXXXXX
  String _escapeTurtleString(String value) {
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      final int codeUnit = value.codeUnitAt(i);

      // Handle common escape sequences
      switch (codeUnit) {
        case 0x08: // backspace
          buffer.write('\\b');
          break;
        case 0x09: // tab
          buffer.write('\\t');
          break;
        case 0x0A: // line feed
          buffer.write('\\n');
          break;
        case 0x0C: // form feed
          buffer.write('\\f');
          break;
        case 0x0D: // carriage return
          buffer.write('\\r');
          break;
        case 0x22: // double quote
          buffer.write('\\"');
          break;
        case 0x5C: // backslash
          buffer.write('\\\\');
          break;
        default:
          if (codeUnit < 0x20 || codeUnit >= 0x7F) {
            // Escape non-printable ASCII and non-ASCII Unicode characters
            if (codeUnit <= 0xFFFF) {
              buffer.write('\\u${codeUnit.toRadixString(16).padLeft(4, '0')}');
            } else {
              buffer.write('\\U${codeUnit.toRadixString(16).padLeft(8, '0')}');
            }
          } else {
            // Regular printable ASCII character
            buffer.writeCharCode(codeUnit);
          }
      }
    }

    return buffer.toString();
  }
}

/// Serializer for serializing RDF graphs to Turtle syntax.
///
/// Turtle is a text-based format for RDF data that is designed to be more
/// readable than other RDF serialization formats. This class implements
/// the serialization logic following the Turtle specification.
class TurtleSerializer implements RdfSerializer {
  final ContextLogger? _logger;

  /// Creates a new TurtleSerializer.
  ///
  /// [loggerService] Optional logger service for debugging.
  TurtleSerializer({LoggerService? loggerService})
    : _logger = loggerService?.createLogger('TurtleSerializer');

  @override
  String write(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> prefixes = const {},
  }) {
    _logger?.debug('Serializing graph to Turtle');

    final buffer = StringBuffer();

    // 1. Write prefixes
    _writePrefixes(buffer, prefixes);

    final prefixesByIri = prefixes.map((prefix, iri) {
      return MapEntry(iri, prefix);
    });
    final RdfTermTurtleStringVisitor visitor = RdfTermTurtleStringVisitor(
      prefixesByIri: prefixesByIri,
    );

    // 2. Write triples grouped by subject
    _writeTriples(buffer, graph.triples, visitor);

    return buffer.toString();
  }

  /// Writes prefix declarations to the output buffer.
  void _writePrefixes(StringBuffer buffer, Map<String, String> prefixes) {
    if (prefixes.isEmpty) {
      return;
    }

    for (final entry in prefixes.entries) {
      buffer.writeln('@prefix ${entry.key}: <${entry.value}> .');
    }

    // Add blank line after prefixes
    buffer.writeln();
  }

  /// Writes all triples to the output buffer, grouped by subject.
  void _writeTriples(
    StringBuffer buffer,
    List<Triple> triples,
    RdfTermVisitor<String> visitor,
  ) {
    if (triples.isEmpty) {
      return;
    }

    // Group triples by subject for more compact representation
    final Map<String, List<Triple>> triplesBySubject = {};

    for (final triple in triples) {
      final subjectStr = triple.subject.accept(visitor);
      triplesBySubject.putIfAbsent(subjectStr, () => []).add(triple);
    }

    // Write each subject group
    var isFirst = true;
    for (final entry in triplesBySubject.entries) {
      if (!isFirst) {
        buffer.writeln();
      }
      isFirst = false;

      _writeSubjectGroup(buffer, entry.key, entry.value, visitor);
    }
  }

  /// Writes a group of triples that share the same subject.
  void _writeSubjectGroup(
    StringBuffer buffer,
    String subjectStr,
    List<Triple> triples,
    RdfTermVisitor<String> visitor,
  ) {
    // Write subject (already in Turtle format)
    buffer.write(subjectStr);

    // Group triples by predicate for more compact representation
    final Map<String, List<Triple>> triplesByPredicate = {};

    for (final triple in triples) {
      final predicateStr = triple.predicate.accept(visitor);
      triplesByPredicate.putIfAbsent(predicateStr, () => []).add(triple);
    }

    // Write predicates and objects
    var predicateIndex = 0;
    for (final entry in triplesByPredicate.entries) {
      final predicateStr = entry.key;
      final predicateTriples = entry.value;

      // First predicate on same line as subject, others indented on new lines
      if (predicateIndex == 0) {
        buffer.write(' ');
      } else {
        buffer.write(';\n    ');
      }
      predicateIndex++;

      // Write predicate with special handling for rdf:type
      buffer.write(predicateStr);

      // Write objects
      for (var i = 0; i < predicateTriples.length; i++) {
        final triple = predicateTriples[i];

        if (i == 0) {
          buffer.write(' ');
        } else {
          buffer.write(', ');
        }

        buffer.write(triple.object.accept(visitor));
      }
    }

    // End the subject group
    buffer.write(' .');
  }
}
