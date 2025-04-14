import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/rdf_constants.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';

import 'turtle_tokenizer.dart';

/// A parser for Turtle syntax, which is a text-based format for representing RDF data.
///
/// Turtle is a syntax for RDF (Resource Description Framework) that provides a way
/// to write RDF triples in a compact and human-readable form. This parser supports:
///
/// - Prefix declarations (@prefix)
/// - IRIs (Internationalized Resource Identifiers)
/// - Prefixed names (e.g., foaf:name)
/// - Blank nodes (anonymous resources)
/// - Literals (strings, numbers, etc.)
/// - Lists of predicate-object pairs
/// - Relative IRI resolution against a base URI
///
/// Example usage:
/// ```dart
/// final parser = TurtleParser('''
///   @prefix foaf: <http://xmlns.com/foaf/0.1/> .
///   <http://example.com/me> foaf:name "John Doe" .
/// ''', baseUri: 'http://example.com/');
/// final triples = parser.parse();
/// ```
///
/// The parser follows a recursive descent approach, with separate methods for
/// parsing different syntactic elements of Turtle.
class TurtleParser {
  final ContextLogger _logger;
  final TurtleTokenizer _tokenizer;
  final Map<String, String> _prefixes = {};
  final String? _baseUri;
  Token _currentToken = Token(TokenType.eof, '', 0, 0);
  final List<Triple> _triples = [];

  /// Creates a new Turtle parser for the given input string.
  ///
  /// [input] is the Turtle document to parse.
  /// [baseUri] is the base URI against which relative IRIs should be resolved.
  /// If not provided, relative IRIs will be kept as-is.
  TurtleParser(String input, {String? baseUri, LoggerService? loggerService})
    : _logger = (loggerService ?? LoggerService()).createLogger('TurtleParser'),
      _tokenizer = TurtleTokenizer(input, loggerService: loggerService),
      _baseUri = baseUri;

  /// Parses the input and returns a list of triples.
  ///
  /// The parser processes the input in the following order:
  /// 1. Prefix declarations (@prefix)
  /// 2. Blank nodes ([...])
  /// 3. Subject-predicate-object triples
  ///
  /// Each triple is added to the result list, and the method returns all
  /// triples found in the input.
  ///
  /// Throws [FormatException] if the input is not valid Turtle syntax.
  List<Triple> parse() {
    _currentToken = _tokenizer.nextToken();
    final triples = <Triple>[];
    _logger.debug('Starting parse with token: $_currentToken');

    while (_currentToken.type != TokenType.eof) {
      _logger.debug('Processing token: $_currentToken');
      if (_currentToken.type == TokenType.prefix) {
        _logger.debug('Found prefix declaration');
        _parsePrefix();
      } else if (_currentToken.type == TokenType.openBracket) {
        _logger.debug('Found blank node');
        _parseBlankNode();
        _expect(TokenType.dot);
        _currentToken = _tokenizer.nextToken();
      } else {
        _logger.debug('Parsing subject');
        final subject = _parseSubject();
        _logger.debug('Subject parsed: $subject');
        _logger.debug('Current token after subject: $_currentToken');

        final predicateObjectList = _parsePredicateObjectList();
        _logger.debug('Predicate-object list parsed: $predicateObjectList');
        _logger.debug(
          'Current token after predicate-object list: $_currentToken',
        );

        for (final po in predicateObjectList) {
          triples.add(Triple(subject, po.predicate, po.object));
        }
        if (_currentToken.type != TokenType.eof) {
          _logger.debug('Expecting dot, current token: $_currentToken');
          _expect(TokenType.dot);
          _currentToken = _tokenizer.nextToken();
        }
      }
    }

    _logger.debug('Parse complete. Found ${triples.length} triples');
    return [...triples, ..._triples];
  }

  /// Parses a prefix declaration.
  ///
  /// A prefix declaration has the form:
  /// ```turtle
  /// @prefix prefix: <iri> .
  /// ```
  ///
  /// The prefix is stored in the [_prefixes] map for later use in expanding
  /// prefixed names.
  void _parsePrefix() {
    _logger.debug('Parsing prefix declaration');
    _expect(TokenType.prefix);
    _currentToken = _tokenizer.nextToken();
    _logger.debug('After @prefix: $_currentToken');

    _expect(TokenType.prefixedName);
    final prefixedName = _currentToken.value;
    _logger.debug('Found prefixed name: $prefixedName');

    // Handle empty prefix case
    final prefix =
        prefixedName == ':'
            ? ''
            : prefixedName.substring(0, prefixedName.length - 1);
    _logger.debug('Extracted prefix: "$prefix"');

    _currentToken = _tokenizer.nextToken();
    _logger.debug('After prefixed name: $_currentToken');

    _expect(TokenType.iri);
    final iriToken = _currentToken.value;
    // Extract IRI value from <...>
    final iri = _extractIriValue(iriToken);
    _logger.debug('Found IRI: $iri');

    _prefixes[prefix] = iri;
    _logger.debug('Stored prefix mapping: "$prefix" -> "$iri"');

    _currentToken = _tokenizer.nextToken();
    _logger.debug('After IRI: $_currentToken');

    _expect(TokenType.dot);
    _currentToken = _tokenizer.nextToken();
    _logger.debug('After dot: $_currentToken');
  }

  /// Parses a subject in a triple.
  ///
  /// A subject can be:
  /// - An IRI (e.g., <http://example.com/foo>)
  /// - A prefixed name (e.g., foaf:Person)
  /// - A blank node (e.g., _:b1)
  /// - A blank node expression (e.g., [ ... ])
  ///
  /// Returns an RdfTerm representing the subject (either IriTerm or BlankNodeTerm)
  RdfSubject _parseSubject() {
    _logger.debug('Parsing subject, current token: $_currentToken');
    if (_currentToken.type == TokenType.iri) {
      final iriValue = _extractIriValue(_currentToken.value);
      final subject = IriTerm(iriValue);
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed IRI subject: $subject');
      return subject;
    } else if (_currentToken.type == TokenType.prefixedName) {
      final expandedIri = _expandPrefixedName(_currentToken.value);
      final subject = IriTerm(expandedIri);
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed prefixed name subject: $subject');
      return subject;
    } else if (_currentToken.type == TokenType.blankNode) {
      final label = _currentToken.value;
      final subject = BlankNodeTerm(label);
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed blank node subject: $subject');
      return subject;
    } else if (_currentToken.type == TokenType.openBracket) {
      _logger.debug('Found blank node expression for subject');
      return _parseBlankNode();
    } else if (_currentToken.type == TokenType.a) {
      // Handle the case where 'a' is used as a subject (which is invalid)
      _logger.error('Invalid use of "a" as subject');
      throw FormatException(
        'Cannot use "a" as a subject at ${_currentToken.line}:${_currentToken.column}',
      );
    } else {
      _logger.error('Unexpected token type for subject: ${_currentToken.type}');
      throw FormatException(
        'Expected subject at ${_currentToken.line}:${_currentToken.column}',
      );
    }
  }

  /// Parses a list of predicate-object pairs.
  ///
  /// A predicate-object list has the form:
  /// ```turtle
  /// predicate1 object1 ;
  /// predicate2 object2 ;
  /// predicate3 object3 .
  /// ```
  ///
  /// Objects can also be comma-separated:
  /// ```turtle
  /// predicate1 object1, object2, object3 ;
  /// predicate2 object4 .
  /// ```
  ///
  /// Returns a list of (predicate, object) pairs that share the same subject.
  List<({IriTerm predicate, RdfObject object})> _parsePredicateObjectList() {
    _logger.debug('Parsing predicate-object list');
    final result = <({IriTerm predicate, RdfObject object})>[];
    var predicate = _parsePredicate();
    _logger.debug('Parsed predicate: $predicate');

    // Parse first object
    var object = _parseObject();
    _logger.debug('Parsed object: $object');
    result.add((predicate: predicate, object: object));

    // Parse additional objects for the same predicate
    while (_currentToken.type == TokenType.comma) {
      _logger.debug('Found comma, parsing next object');
      _currentToken = _tokenizer.nextToken();
      object = _parseObject();
      _logger.debug('Parsed next object: $object');
      result.add((predicate: predicate, object: object));
    }

    // Parse additional predicate-object pairs
    while (_currentToken.type == TokenType.semicolon) {
      _logger.debug('Found semicolon, parsing next predicate-object pair');
      _currentToken = _tokenizer.nextToken();
      if (_currentToken.type == TokenType.dot ||
          _currentToken.type == TokenType.closeBracket) {
        _logger.debug('End of predicate-object list reached');
        break;
      }
      predicate = _parsePredicate();
      _logger.debug('Parsed next predicate: $predicate');
      object = _parseObject();
      _logger.debug('Parsed next object: $object');
      result.add((predicate: predicate, object: object));

      // Parse additional objects for this predicate
      while (_currentToken.type == TokenType.comma) {
        _logger.debug('Found comma, parsing next object');
        _currentToken = _tokenizer.nextToken();
        object = _parseObject();
        _logger.debug('Parsed next object: $object');
        result.add((predicate: predicate, object: object));
      }
    }

    _logger.debug('Predicate-object list complete: $result');
    return result;
  }

  /// Parses a predicate in a triple.
  ///
  /// A predicate can be:
  /// - The special 'a' keyword (expands to rdf:type)
  /// - An IRI (e.g., <http://example.com/bar>)
  /// - A prefixed name (e.g., foaf:name)
  ///
  /// Returns an IriTerm representing the predicate.
  IriTerm _parsePredicate() {
    _logger.debug('Parsing predicate, current token: $_currentToken');
    if (_currentToken.type == TokenType.a) {
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Found "a" keyword, expanded to rdf:type');
      return RdfConstants.typeIri;
    } else if (_currentToken.type == TokenType.iri) {
      final iriValue = _extractIriValue(_currentToken.value);
      final predicate = IriTerm(iriValue);
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed IRI predicate: $predicate');
      return predicate;
    } else if (_currentToken.type == TokenType.prefixedName) {
      final expandedIri = _expandPrefixedName(_currentToken.value);
      final predicate = IriTerm(expandedIri);
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed prefixed name predicate: $predicate');
      return predicate;
    } else {
      _logger.error(
        'Unexpected token type for predicate: ${_currentToken.type}',
      );
      throw FormatException(
        'Expected predicate at ${_currentToken.line}:${_currentToken.column}',
      );
    }
  }

  /// Parses an object in a triple.
  ///
  /// An object can be:
  /// - An IRI (e.g., <http://example.com/baz>)
  /// - A prefixed name (e.g., foaf:Person)
  /// - A blank node (e.g., _:b1)
  /// - A literal (e.g., "Hello, World!")
  /// - A blank node expression (e.g., [ ... ])
  ///
  /// Returns an RdfTerm representing the object (IriTerm, BlankNodeTerm, or LiteralTerm).
  RdfObject _parseObject() {
    _logger.debug('Parsing object, current token: $_currentToken');
    if (_currentToken.type == TokenType.iri) {
      final iriValue = _extractIriValue(_currentToken.value);
      final object = IriTerm(iriValue);
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed IRI object: $object');
      return object;
    } else if (_currentToken.type == TokenType.prefixedName) {
      final expandedIri = _expandPrefixedName(_currentToken.value);
      final object = IriTerm(expandedIri);
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed prefixed name object: $object');
      return object;
    } else if (_currentToken.type == TokenType.blankNode) {
      final label = _currentToken.value;
      final object = BlankNodeTerm(label);
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed blank node object: $object');
      return object;
    } else if (_currentToken.type == TokenType.literal) {
      final literalTerm = _parseLiteralValue(_currentToken.value);
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed literal object: $literalTerm');
      return literalTerm;
    } else if (_currentToken.type == TokenType.openBracket) {
      _logger.debug('Found blank node expression for object');
      return _parseBlankNode();
    } else {
      _logger.error('Unexpected token type for object: ${_currentToken.type}');
      throw FormatException(
        'Expected object at ${_currentToken.line}:${_currentToken.column}',
      );
    }
  }

  /// Parses a blank node expression.
  ///
  /// A blank node expression has the form:
  /// ```turtle
  /// [ predicate1 object1 ;
  ///   predicate2 object2 ;
  ///   predicate3 object3 ]
  /// ```
  ///
  /// Returns a BlankNodeTerm and adds any triples found within the blank node
  /// to the [_triples] list.
  BlankNodeTerm _parseBlankNode() {
    _logger.debug('Parsing blank node');
    _expect(TokenType.openBracket);
    final blankNodeId = 'b${_currentToken.line}${_currentToken.column}';
    final subject = BlankNodeTerm(blankNodeId);
    _logger.debug('Generated blank node identifier: $subject');
    _currentToken = _tokenizer.nextToken();

    if (_currentToken.type != TokenType.closeBracket) {
      _logger.debug('Found blank node content');
      final predicateObjectList = _parsePredicateObjectList();
      for (final po in predicateObjectList) {
        _triples.add(Triple(subject, po.predicate, po.object));
      }
      _expect(TokenType.closeBracket);
      _currentToken = _tokenizer.nextToken();
    } else {
      _logger.debug('Empty blank node');
      _currentToken = _tokenizer.nextToken();
    }
    return subject;
  }

  /// Extracts the IRI value from a Turtle IRI token.
  ///
  /// Removes the enclosing angle brackets (<...>).
  String _extractIriValue(String iriToken) {
    if (iriToken.startsWith('<') && iriToken.endsWith('>')) {
      return iriToken.substring(1, iriToken.length - 1);
    }
    return iriToken;
  }

  /// Parses a literal value from a Turtle literal token.
  ///
  /// Handles simple literals, language-tagged literals, and datatyped literals.
  /// Properly unescapes any escape sequences in the literal value according to
  /// Turtle syntax rules.
  LiteralTerm _parseLiteralValue(String literalToken) {
    _logger.debug('Parsing literal token: $literalToken');

    // Extract the literal content (between the quotes)
    final valueMatch = RegExp(
      r'"([^"\\]*(?:\\.[^"\\]*)*)"',
    ).firstMatch(literalToken);
    if (valueMatch == null) {
      _logger.error('Invalid literal format: $literalToken');
      throw FormatException('Invalid literal format: $literalToken');
    }

    final escapedValue = valueMatch.group(1)!;
    final value = _unescapeTurtleString(escapedValue);

    // Check for language tag (@lang)
    final langMatch = RegExp(r'@([a-zA-Z\-]+)$').firstMatch(literalToken);
    if (langMatch != null) {
      final lang = langMatch.group(1)!;
      return LiteralTerm.withLanguage(value, lang);
    }

    // Check for datatype (^^<datatype>)
    final datatypeMatch = RegExp(r'\^\^<([^>]+)>$').firstMatch(literalToken);
    if (datatypeMatch != null) {
      final datatype = IriTerm(datatypeMatch.group(1)!);
      return LiteralTerm(value, datatype: datatype);
    }

    // Check for datatype with prefixed name (^^prefix:localName)
    final prefixedDatatypeMatch = RegExp(
      r'\^\^([a-zA-Z0-9_\-]+:[a-zA-Z0-9_\-]+)$',
    ).firstMatch(literalToken);
    if (prefixedDatatypeMatch != null) {
      final prefixedName = prefixedDatatypeMatch.group(1)!;
      final expandedIri = _expandPrefixedName(prefixedName);
      final datatype = IriTerm(expandedIri);
      return LiteralTerm(value, datatype: datatype);
    }

    // Simple literal
    return LiteralTerm.string(value);
  }

  /// Unescapes a string according to Turtle syntax rules.
  ///
  /// This is the inverse operation of _escapeTurtleString in TurtleSerializer.
  /// It handles standard escape sequences (\n, \r, \t, etc.) and Unicode
  /// escape sequences (\uXXXX and \UXXXXXXXX).
  String _unescapeTurtleString(String value) {
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      // Handle escape sequences
      if (value[i] == '\\' && i + 1 < value.length) {
        final nextChar = value[i + 1];
        switch (nextChar) {
          case 'b': // backspace
            buffer.writeCharCode(0x08);
            i++;
            break;
          case 't': // tab
            buffer.writeCharCode(0x09);
            i++;
            break;
          case 'n': // line feed
            buffer.writeCharCode(0x0A);
            i++;
            break;
          case 'f': // form feed
            buffer.writeCharCode(0x0C);
            i++;
            break;
          case 'r': // carriage return
            buffer.writeCharCode(0x0D);
            i++;
            break;
          case '"': // double quote
            buffer.writeCharCode(0x22);
            i++;
            break;
          case '\\': // backslash
            buffer.writeCharCode(0x5C);
            i++;
            break;
          case 'u': // 4-digit Unicode escape (e.g., \u00A9)
            if (i + 5 < value.length) {
              final hexCode = value.substring(i + 2, i + 6);
              try {
                final codeUnit = int.parse(hexCode, radix: 16);
                buffer.writeCharCode(codeUnit);
                i += 5;
              } catch (e) {
                // Invalid Unicode escape, treat as literal characters
                buffer.write('\\u$hexCode');
                i += 5;
              }
            } else {
              // Incomplete escape, treat as literal characters
              buffer.write('\\u');
              i++;
            }
            break;
          case 'U': // 8-digit Unicode escape (e.g., \U0001F600)
            if (i + 9 < value.length) {
              final hexCode = value.substring(i + 2, i + 10);
              try {
                final codeUnit = int.parse(hexCode, radix: 16);
                buffer.writeCharCode(codeUnit);
                i += 9;
              } catch (e) {
                // Invalid Unicode escape, treat as literal characters
                buffer.write('\\U$hexCode');
                i += 9;
              }
            } else {
              // Incomplete escape, treat as literal characters
              buffer.write('\\U');
              i++;
            }
            break;
          default:
            // Unrecognized escape, treat as literal characters
            buffer.write('\\$nextChar');
            i++;
        }
      } else {
        // Normal character
        buffer.write(value[i]);
      }
    }

    return buffer.toString();
  }

  /// Expands a prefixed name to a full IRI.
  ///
  /// A prefixed name has the form "prefix:localName". This method:
  /// 1. Splits the prefixed name into prefix and local name parts
  /// 2. Looks up the prefix in the [_prefixes] map
  /// 3. Concatenates the IRI from the prefix map with the local name
  /// 4. If the result is a relative IRI and [_baseUri] is set, resolves it against the base URI
  ///
  /// Example:
  /// ```dart
  /// _prefixes['foaf'] = 'http://xmlns.com/foaf/0.1/';
  /// _expandPrefixedName('foaf:name') // Returns 'http://xmlns.com/foaf/0.1/name'
  /// ```
  String _expandPrefixedName(String prefixedName) {
    _logger.debug('Expanding prefixed name: $prefixedName');
    final parts = prefixedName.split(':');
    if (parts.length != 2) {
      _logger.error('Invalid prefixed name format: $prefixedName');
      throw FormatException('Invalid prefixed name: $prefixedName');
    }
    final prefix = parts[0];
    final localName = parts[1];
    if (!_prefixes.containsKey(prefix)) {
      _logger.error('Unknown prefix: $prefix');
      throw FormatException('Unknown prefix: $prefix');
    }
    final expanded = '${_prefixes[prefix]}$localName';
    _logger.debug('Expanded prefixed name: $prefixedName -> $expanded');

    // Resolve relative IRIs against the base URI if one is provided
    if (_baseUri != null && !expanded.startsWith('http')) {
      if (expanded.startsWith('/')) {
        // Path-absolute IRI
        final baseUri = Uri.parse(_baseUri);
        final resolved =
            Uri(
              scheme: baseUri.scheme,
              host: baseUri.host,
              path: expanded,
            ).toString();
        _logger.debug('Resolved path-absolute IRI: $expanded -> $resolved');
        return resolved;
      } else {
        // Relative IRI
        final resolved = Uri.parse(_baseUri).resolve(expanded).toString();
        _logger.debug('Resolved relative IRI: $expanded -> $resolved');
        return resolved;
      }
    }

    return expanded;
  }

  /// Verifies that the current token is of the expected type.
  ///
  /// Throws a [FormatException] if the current token's type does not match
  /// the expected type, including line and column information in the error message.
  void _expect(TokenType type) {
    _logger.debug('Expecting token type: $type, found: ${_currentToken.type}');
    if (_currentToken.type != type) {
      _logger.error(
        'Token type mismatch: expected $type but found ${_currentToken.type}',
      );
      throw FormatException(
        'Expected $type but found ${_currentToken.type} at ${_currentToken.line}:${_currentToken.column}',
      );
    }
  }
}
