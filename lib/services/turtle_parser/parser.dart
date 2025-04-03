import 'package:my_cross_platform_app/services/logger_service.dart';
import 'tokenizer.dart';

/// Represents an RDF triple in Turtle syntax.
///
/// A triple consists of three components:
/// - subject: The resource being described
/// - predicate: The property or relationship
/// - object: The value or related resource
///
/// Example:
/// ```turtle
/// <http://example.com/foo> <http://example.com/bar> "baz" .
/// ```
/// In this example:
/// - subject: "http://example.com/foo"
/// - predicate: "http://example.com/bar"
/// - object: "baz"
class Triple {
  /// The subject of the triple, representing the resource being described.
  final String subject;

  /// The predicate of the triple, representing the property or relationship.
  final String predicate;

  /// The object of the triple, representing the value or related resource.
  final String object;

  Triple(this.subject, this.predicate, this.object);

  @override
  String toString() => '<$subject> <$predicate> <$object> .';
}

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
  static final _logger = LoggerService().createLogger('TurtleParser');
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
  TurtleParser(String input, {String? baseUri})
    : _tokenizer = TurtleTokenizer(input),
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
    final iri = _currentToken.value;
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
  /// Returns the expanded form of the subject (IRIs are kept as-is, prefixed names
  /// are expanded using the prefix map).
  String _parseSubject() {
    _logger.debug('Parsing subject, current token: $_currentToken');
    if (_currentToken.type == TokenType.iri) {
      final subject = _currentToken.value;
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed IRI subject: $subject');
      return subject;
    } else if (_currentToken.type == TokenType.prefixedName) {
      final subject = _expandPrefixedName(_currentToken.value);
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed prefixed name subject: $subject');
      return subject;
    } else if (_currentToken.type == TokenType.blankNode) {
      final subject = _currentToken.value;
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
  List<({String predicate, String object})> _parsePredicateObjectList() {
    _logger.debug('Parsing predicate-object list');
    final result = <({String predicate, String object})>[];
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
  /// Returns the expanded form of the predicate.
  String _parsePredicate() {
    _logger.debug('Parsing predicate, current token: $_currentToken');
    if (_currentToken.type == TokenType.a) {
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Found "a" keyword, expanded to rdf:type');
      return 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type';
    } else if (_currentToken.type == TokenType.iri) {
      final predicate = _currentToken.value;
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed IRI predicate: $predicate');
      return predicate;
    } else if (_currentToken.type == TokenType.prefixedName) {
      final predicate = _expandPrefixedName(_currentToken.value);
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
  /// Returns the expanded form of the object.
  String _parseObject() {
    _logger.debug('Parsing object, current token: $_currentToken');
    if (_currentToken.type == TokenType.iri) {
      final object = _currentToken.value;
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed IRI object: $object');
      return object;
    } else if (_currentToken.type == TokenType.prefixedName) {
      final object = _expandPrefixedName(_currentToken.value);
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed prefixed name object: $object');
      return object;
    } else if (_currentToken.type == TokenType.blankNode) {
      final object = _currentToken.value;
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed blank node object: $object');
      return object;
    } else if (_currentToken.type == TokenType.literal) {
      final object = _currentToken.value;
      _currentToken = _tokenizer.nextToken();
      _logger.debug('Parsed literal object: $object');
      return object;
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
  /// Returns a generated blank node identifier (e.g., _:b123) and adds any
  /// triples found within the blank node to the [_triples] list.
  String _parseBlankNode() {
    _logger.debug('Parsing blank node');
    _expect(TokenType.openBracket);
    final subject = '_:b${_currentToken.line}${_currentToken.column}';
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
        final baseUri = Uri.parse(_baseUri!);
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
        final resolved = Uri.parse(_baseUri!).resolve(expanded).toString();
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
