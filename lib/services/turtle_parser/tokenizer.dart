import 'package:my_cross_platform_app/services/logger_service.dart';

/// Token types in Turtle syntax.
///
/// Turtle syntax consists of several types of tokens:
/// - [prefix]: The '@prefix' keyword for prefix declarations
/// - [iri]: Internationalized Resource Identifiers (e.g., <http://example.com/foo>)
/// - [blankNode]: Anonymous resources (e.g., _:b1)
/// - [literal]: String values (e.g., "Hello, World!")
/// - [dot]: The '.' character that terminates statements
/// - [semicolon]: The ';' character that separates predicate-object pairs
/// - [comma]: The ',' character that separates objects in lists
/// - [openBracket]: The '[' character that starts blank node expressions
/// - [closeBracket]: The ']' character that ends blank node expressions
/// - [openParen]: The '(' character that starts collections
/// - [closeParen]: The ')' character that ends collections
/// - [a]: The 'a' keyword (shorthand for rdf:type)
/// - [prefixedName]: Names with prefixes (e.g., foaf:name)
/// - [eof]: End of file marker
enum TokenType {
  prefix,
  iri,
  blankNode,
  literal,
  dot,
  semicolon,
  comma,
  openBracket,
  closeBracket,
  openParen,
  closeParen,
  a,
  prefixedName,
  eof,
}

/// A token in Turtle syntax.
///
/// Each token has:
/// - [type]: The kind of token (see [TokenType])
/// - [value]: The actual text content of the token
/// - [line]: The line number where the token starts
/// - [column]: The column number where the token starts
///
/// Example:
/// ```dart
/// Token(TokenType.iri, "http://example.com/foo", 1, 1)
/// ```
class Token {
  /// The type of this token.
  final TokenType type;

  /// The text content of this token.
  final String value;

  /// The line number where this token starts (1-based).
  final int line;

  /// The column number where this token starts (1-based).
  final int column;

  Token(this.type, this.value, this.line, this.column);

  @override
  String toString() => 'Token($type, "$value", $line:$column)';
}

/// Tokenizer for Turtle syntax.
///
/// This class is responsible for breaking down Turtle input into a sequence of tokens.
/// It implements a simple state machine that:
/// 1. Skips whitespace and comments
/// 2. Identifies the start of each token
/// 3. Parses the complete token
/// 4. Returns the token with its type and position
///
/// The tokenizer handles all Turtle syntax elements:
/// - Prefix declarations (@prefix)
/// - IRIs (<...>)
/// - Blank nodes (_:...)
/// - Literals ("...")
/// - Prefixed names (prefix:localName)
/// - Special keywords ('a')
/// - Punctuation (., ;, [, ], etc.)
///
/// Example usage:
/// ```dart
/// final tokenizer = TurtleTokenizer('@prefix foaf: <http://xmlns.com/foaf/0.1/> .');
/// Token token;
/// while ((token = tokenizer.nextToken()).type != TokenType.eof) {
///   print(token);
/// }
/// ```
class TurtleTokenizer {
  static final _logger = LoggerService();
  final String _input;
  int _position = 0;
  int _line = 1;
  int _column = 1;

  /// Creates a new tokenizer for the given input string.
  TurtleTokenizer(this._input);

  /// Gets the next token from the input.
  ///
  /// This method:
  /// 1. Skips any whitespace and comments
  /// 2. Identifies the type of the next token
  /// 3. Parses the complete token
  /// 4. Returns a [Token] with its type, value, and position
  ///
  /// Returns [TokenType.eof] when the end of input is reached.
  ///
  /// Throws [FormatException] if an unexpected character is encountered.
  Token nextToken() {
    _skipWhitespace();

    if (_position >= _input.length) {
      return Token(TokenType.eof, '', _line, _column);
    }

    final char = _input[_position];
    _logger.debug('Current char: "$char" at $_line:$_column');

    // Handle single character tokens
    switch (char) {
      case '.':
        _position++;
        _column++;
        return Token(TokenType.dot, '.', _line, _column - 1);
      case ';':
        _position++;
        _column++;
        return Token(TokenType.semicolon, ';', _line, _column - 1);
      case ',':
        _position++;
        _column++;
        return Token(TokenType.comma, ',', _line, _column - 1);
      case '[':
        _position++;
        _column++;
        return Token(TokenType.openBracket, '[', _line, _column - 1);
      case ']':
        _position++;
        _column++;
        return Token(TokenType.closeBracket, ']', _line, _column - 1);
      case '(':
        _position++;
        _column++;
        return Token(TokenType.openParen, '(', _line, _column - 1);
      case ')':
        _position++;
        _column++;
        return Token(TokenType.closeParen, ')', _line, _column - 1);
    }

    // Handle @prefix
    if (_startsWith('@prefix')) {
      _position += 7;
      _column += 7;
      return Token(TokenType.prefix, '@prefix', _line, _column - 7);
    }

    // Handle 'a'
    if (_startsWith('a ') || _startsWith('a\n') || _startsWith('a\t')) {
      _position++;
      _column++;
      return Token(TokenType.a, 'a', _line, _column - 1);
    }

    // Handle IRIs
    if (char == '<') {
      return _parseIri();
    }

    // Handle blank nodes
    if (char == '_' &&
        _position + 1 < _input.length &&
        _input[_position + 1] == ':') {
      return _parseBlankNode();
    }

    // Handle literals
    if (char == '"') {
      return _parseLiteral();
    }

    // Handle prefixed names
    if (_isNameStartChar(char)) {
      _logger.debug('Starting prefixed name with char: "$char"');
      return _parsePrefixedName();
    }

    _logger.error('Unexpected character: $char at $_line:$_column');
    throw FormatException('Unexpected character: $char at $_line:$_column');
  }

  /// Skips whitespace and comments in the input.
  ///
  /// This method:
  /// 1. Advances past spaces, tabs, and carriage returns
  /// 2. Handles line breaks by incrementing the line counter
  /// 3. Skips comments (text after # until end of line)
  void _skipWhitespace() {
    while (_position < _input.length) {
      final char = _input[_position];
      if (char == '\n') {
        _line++;
        _column = 1;
        _position++;
      } else if (char == ' ' || char == '\t' || char == '\r') {
        _column++;
        _position++;
      } else if (char == '#') {
        _skipComment();
      } else {
        break;
      }
    }
  }

  /// Skips a comment in the input.
  ///
  /// Comments in Turtle start with # and continue until the end of the line.
  void _skipComment() {
    while (_position < _input.length && _input[_position] != '\n') {
      _position++;
    }
  }

  /// Parses an IRI token.
  ///
  /// IRIs in Turtle are enclosed in angle brackets (<...>).
  /// They can contain escaped characters (using backslash).
  ///
  /// Example:
  /// ```turtle
  /// <http://example.com/foo>
  /// ```
  ///
  /// Throws [FormatException] if the IRI is not properly closed.
  Token _parseIri() {
    final startLine = _line;
    final startColumn = _column;
    _position++; // Skip opening <
    _column++;

    final buffer = StringBuffer();
    while (_position < _input.length && _input[_position] != '>') {
      if (_input[_position] == '\\') {
        _position++;
        _column++;
        if (_position < _input.length) {
          buffer.write(_input[_position]);
          _position++;
          _column++;
        }
      } else {
        buffer.write(_input[_position]);
        _position++;
        _column++;
      }
    }

    if (_position >= _input.length) {
      throw FormatException('Unclosed IRI at $startLine:$startColumn');
    }

    _position++; // Skip closing >
    _column++;

    return Token(TokenType.iri, buffer.toString(), startLine, startColumn);
  }

  /// Parses a blank node token.
  ///
  /// Blank nodes in Turtle start with _: followed by a name.
  /// They represent anonymous resources.
  ///
  /// Example:
  /// ```turtle
  /// _:b1
  /// ```
  Token _parseBlankNode() {
    final startLine = _line;
    final startColumn = _column;
    final buffer = StringBuffer();

    // Skip the _: prefix
    _position += 2;
    _column += 2;
    buffer.write('_:');

    while (_position < _input.length && _isNameChar(_input[_position])) {
      buffer.write(_input[_position]);
      _position++;
      _column++;
    }

    return Token(
      TokenType.blankNode,
      buffer.toString(),
      startLine,
      startColumn,
    );
  }

  /// Parses a literal token.
  ///
  /// Literals in Turtle are enclosed in double quotes.
  /// They can have:
  /// - Language tags (@en)
  /// - Type specifiers (^^<...>)
  /// - Escaped characters (using backslash)
  ///
  /// Examples:
  /// ```turtle
  /// "Hello, World!"
  /// "Bonjour"@fr
  /// "42"^^<http://www.w3.org/2001/XMLSchema#integer>
  /// ```
  ///
  /// Throws [FormatException] if the literal is not properly closed.
  Token _parseLiteral() {
    final startLine = _line;
    final startColumn = _column;
    _position++; // Skip opening "
    _column++;

    final buffer = StringBuffer();
    while (_position < _input.length && _input[_position] != '"') {
      if (_input[_position] == '\\') {
        _position++;
        _column++;
        if (_position < _input.length) {
          buffer.write(_input[_position]);
          _position++;
          _column++;
        }
      } else {
        buffer.write(_input[_position]);
        _position++;
        _column++;
      }
    }

    if (_position >= _input.length) {
      throw FormatException('Unclosed literal at $startLine:$startColumn');
    }

    _position++; // Skip closing "
    _column++;

    // Check for language tag
    if (_position < _input.length && _input[_position] == '@') {
      _position++; // Skip @
      _column++;

      final langBuffer = StringBuffer();
      while (_position < _input.length && _isNameChar(_input[_position])) {
        langBuffer.write(_input[_position]);
        _position++;
        _column++;
      }

      return Token(
        TokenType.literal,
        '${buffer.toString()}@${langBuffer.toString()}',
        startLine,
        startColumn,
      );
    }

    // Check for type specifier
    if (_position + 1 < _input.length &&
        _input[_position] == '^' &&
        _input[_position + 1] == '^') {
      _position += 2; // Skip ^^
      _column += 2;

      // Parse the type IRI
      if (_position < _input.length && _input[_position] == '<') {
        final typeToken = _parseIri();
        return Token(
          TokenType.literal,
          '${buffer.toString()}^^${typeToken.value}',
          startLine,
          startColumn,
        );
      }
    }

    return Token(TokenType.literal, buffer.toString(), startLine, startColumn);
  }

  /// Parses a prefixed name token.
  ///
  /// Prefixed names in Turtle have the form prefix:localName.
  /// The prefix can be empty (just :localName).
  ///
  /// Examples:
  /// ```turtle
  /// foaf:name
  /// :me
  /// ```
  Token _parsePrefixedName() {
    final startLine = _line;
    final startColumn = _column;
    final buffer = StringBuffer();
    _logger.debug('Starting prefixed name at $startLine:$startColumn');

    // Handle empty prefix case (just a colon)
    if (_position < _input.length && _input[_position] == ':') {
      buffer.write(':');
      _position++;
      _column++;
      _logger.debug('Found empty prefix');
      // If there's a local name after the colon, parse it
      if (_position < _input.length && _isNameStartChar(_input[_position])) {
        while (_position < _input.length && _isNameChar(_input[_position])) {
          buffer.write(_input[_position]);
          _position++;
          _column++;
        }
      }
      return Token(
        TokenType.prefixedName,
        buffer.toString(),
        startLine,
        startColumn,
      );
    }

    while (_position < _input.length) {
      final char = _input[_position];
      _logger.debug('Processing char in prefixed name: "$char"');

      if (_isNameChar(char)) {
        buffer.write(char);
        _position++;
        _column++;
      } else if (char == ':') {
        buffer.write(char);
        _position++;
        _column++;
        // Check if there's a local name after the colon
        if (_position < _input.length && _isNameStartChar(_input[_position])) {
          while (_position < _input.length && _isNameChar(_input[_position])) {
            buffer.write(_input[_position]);
            _position++;
            _column++;
          }
        }
        _logger.debug('Found prefixed name: ${buffer.toString()}');
        return Token(
          TokenType.prefixedName,
          buffer.toString(),
          startLine,
          startColumn,
        );
      } else {
        break;
      }
    }

    _logger.debug('Found incomplete prefixed name: ${buffer.toString()}');
    return Token(
      TokenType.prefixedName,
      buffer.toString(),
      startLine,
      startColumn,
    );
  }

  /// Checks if the input at the current position starts with the given prefix.
  bool _startsWith(String prefix) {
    if (_position + prefix.length > _input.length) return false;
    return _input.substring(_position, _position + prefix.length) == prefix;
  }

  /// Checks if a character is valid as the start of a name.
  ///
  /// In Turtle, name start characters are:
  /// - Letters (a-z, A-Z)
  /// - Underscore (_)
  /// - Colon (:)
  bool _isNameStartChar(String char) {
    return RegExp(r'[a-zA-Z_:]').hasMatch(char);
  }

  /// Checks if a character is valid in a name.
  ///
  /// In Turtle, name characters are:
  /// - Letters (a-z, A-Z)
  /// - Digits (0-9)
  /// - Underscore (_)
  /// - Hyphen (-)
  /// - Period (.)
  bool _isNameChar(String char) {
    return RegExp(r'[a-zA-Z0-9_\-.]').hasMatch(char);
  }
}
