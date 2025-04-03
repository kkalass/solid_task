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
///
/// Example usage:
/// ```dart
/// final parser = TurtleParser('''
///   @prefix foaf: <http://xmlns.com/foaf/0.1/> .
///   <http://example.com/me> foaf:name "John Doe" .
/// ''');
/// final triples = parser.parse();
/// ```
///
/// The parser follows a recursive descent approach, with separate methods for
/// parsing different syntactic elements of Turtle.
class TurtleParser {
  static final _logger = LoggerService();
  final TurtleTokenizer _tokenizer;
  final Map<String, String> _prefixes = {};
  Token _currentToken = Token(TokenType.eof, '', 0, 0);
  final List<Triple> _triples = [];

  /// Creates a new Turtle parser for the given input string.
  TurtleParser(String input) : _tokenizer = TurtleTokenizer(input);

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

    while (_currentToken.type != TokenType.eof) {
      if (_currentToken.type == TokenType.prefix) {
        _parsePrefix();
      } else if (_currentToken.type == TokenType.openBracket) {
        _parseBlankNode();
        _expect(TokenType.dot);
        _currentToken = _tokenizer.nextToken();
      } else {
        final subject = _parseSubject();
        final predicateObjectList = _parsePredicateObjectList();
        for (final po in predicateObjectList) {
          triples.add(Triple(subject, po.predicate, po.object));
        }
        if (_currentToken.type != TokenType.eof) {
          _expect(TokenType.dot);
          _currentToken = _tokenizer.nextToken();
        }
      }
    }

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
    _expect(TokenType.prefix);
    _currentToken = _tokenizer.nextToken();
    _expect(TokenType.prefixedName);
    final prefixedName = _currentToken.value;
    // Handle empty prefix case
    final prefix =
        prefixedName == ':'
            ? ''
            : prefixedName.substring(0, prefixedName.length - 1);
    _currentToken = _tokenizer.nextToken();
    _expect(TokenType.iri);
    final iri = _currentToken.value;
    _prefixes[prefix] = iri;
    _currentToken = _tokenizer.nextToken();
    _expect(TokenType.dot);
    _currentToken = _tokenizer.nextToken();
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
    if (_currentToken.type == TokenType.iri) {
      final subject = _currentToken.value;
      _currentToken = _tokenizer.nextToken();
      return subject;
    } else if (_currentToken.type == TokenType.prefixedName) {
      final subject = _expandPrefixedName(_currentToken.value);
      _currentToken = _tokenizer.nextToken();
      return subject;
    } else if (_currentToken.type == TokenType.blankNode) {
      final subject = _currentToken.value;
      _currentToken = _tokenizer.nextToken();
      return subject;
    } else if (_currentToken.type == TokenType.openBracket) {
      return _parseBlankNode();
    } else {
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
  /// Returns a list of (predicate, object) pairs that share the same subject.
  List<({String predicate, String object})> _parsePredicateObjectList() {
    final result = <({String predicate, String object})>[];
    var predicate = _parsePredicate();
    var object = _parseObject();
    result.add((predicate: predicate, object: object));

    while (_currentToken.type == TokenType.semicolon) {
      _currentToken = _tokenizer.nextToken();
      if (_currentToken.type == TokenType.dot ||
          _currentToken.type == TokenType.closeBracket) {
        break;
      }
      predicate = _parsePredicate();
      object = _parseObject();
      result.add((predicate: predicate, object: object));
    }

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
    if (_currentToken.type == TokenType.a) {
      _currentToken = _tokenizer.nextToken();
      return 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type';
    } else if (_currentToken.type == TokenType.iri) {
      final predicate = _currentToken.value;
      _currentToken = _tokenizer.nextToken();
      return predicate;
    } else if (_currentToken.type == TokenType.prefixedName) {
      final predicate = _expandPrefixedName(_currentToken.value);
      _currentToken = _tokenizer.nextToken();
      return predicate;
    } else {
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
    if (_currentToken.type == TokenType.iri) {
      final object = _currentToken.value;
      _currentToken = _tokenizer.nextToken();
      return object;
    } else if (_currentToken.type == TokenType.prefixedName) {
      final object = _expandPrefixedName(_currentToken.value);
      _currentToken = _tokenizer.nextToken();
      return object;
    } else if (_currentToken.type == TokenType.blankNode) {
      final object = _currentToken.value;
      _currentToken = _tokenizer.nextToken();
      return object;
    } else if (_currentToken.type == TokenType.literal) {
      final object = _currentToken.value;
      _currentToken = _tokenizer.nextToken();
      return object;
    } else if (_currentToken.type == TokenType.openBracket) {
      return _parseBlankNode();
    } else {
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
    _expect(TokenType.openBracket);
    final subject = '_:b${_currentToken.line}${_currentToken.column}';
    _currentToken = _tokenizer.nextToken();

    if (_currentToken.type != TokenType.closeBracket) {
      final predicateObjectList = _parsePredicateObjectList();
      for (final po in predicateObjectList) {
        _triples.add(Triple(subject, po.predicate, po.object));
      }
      _expect(TokenType.closeBracket);
      _currentToken = _tokenizer.nextToken();
    } else {
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
  ///
  /// Example:
  /// ```dart
  /// _prefixes['foaf'] = 'http://xmlns.com/foaf/0.1/';
  /// _expandPrefixedName('foaf:name') // Returns 'http://xmlns.com/foaf/0.1/name'
  /// ```
  String _expandPrefixedName(String prefixedName) {
    final parts = prefixedName.split(':');
    if (parts.length != 2) {
      throw FormatException('Invalid prefixed name: $prefixedName');
    }
    final prefix = parts[0];
    final localName = parts[1];
    if (!_prefixes.containsKey(prefix)) {
      throw FormatException('Unknown prefix: $prefix');
    }
    return '${_prefixes[prefix]}$localName';
  }

  /// Verifies that the current token is of the expected type.
  ///
  /// Throws a [FormatException] if the current token's type does not match
  /// the expected type, including line and column information in the error message.
  void _expect(TokenType type) {
    if (_currentToken.type != type) {
      throw FormatException(
        'Expected $type but found ${_currentToken.type} at ${_currentToken.line}:${_currentToken.column}',
      );
    }
  }
}
