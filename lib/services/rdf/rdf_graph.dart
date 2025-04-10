import 'package:solid_task/services/logger_service.dart';

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

/// Represents an RDF graph with prefix handling
class RdfGraph {
  final ContextLogger _logger;
  final Map<String, String> _prefixes = {};
  final List<Triple> _triples = [];

  RdfGraph({LoggerService? loggerService})
    : _logger = (loggerService ?? LoggerService()).createLogger("RdfGraph");

  static RdfGraph fromTriples(
    List<Triple> triples, {
    LoggerService? loggerService,
  }) {
    final graph = RdfGraph(loggerService: loggerService);
    for (final triple in triples) {
      graph.addTriple(
        Triple(
          graph.expandIri(triple.subject),
          graph.expandIri(triple.predicate),
          graph.expandIri(triple.object),
        ),
      );
    }

    return graph;
  }

  /// Add a prefix mapping
  void addPrefix(String prefix, String iri) {
    _prefixes[prefix] = iri;
  }

  /// Add a triple to the graph
  void addTriple(Triple triple) {
    _triples.add(triple);
  }

  /// Expand a prefixed IRI to a full IRI
  String expandIri(String iri) {
    if (iri.startsWith('http://') || iri.startsWith('https://')) {
      return iri;
    }

    final parts = iri.split(':');
    if (parts.length != 2) {
      return iri;
    }

    final prefix = parts[0];
    final localName = parts[1];

    if (!_prefixes.containsKey(prefix)) {
      _logger.warning('Unknown prefix: $prefix');
      return iri;
    }

    return '${_prefixes[prefix]}$localName';
  }

  /// Find all triples matching the given pattern
  List<Triple> findTriples({
    String? subject,
    String? predicate,
    String? object,
  }) {
    return _triples.where((triple) {
      if (subject != null && triple.subject != subject) return false;
      if (predicate != null && triple.predicate != predicate) return false;
      if (object != null && triple.object != object) return false;
      return true;
    }).toList();
  }

  /// Get all triples in the graph
  List<Triple> get triples => List.unmodifiable(_triples);

  /// Get all prefixes in the graph
  Map<String, String> get prefixes => Map.unmodifiable(_prefixes);
}
