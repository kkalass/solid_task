import 'package:solid_task/services/logger_service.dart';
import 'parser.dart';

/// Represents an RDF graph with prefix handling
class RdfGraph {
  static final _logger = LoggerService().createLogger("RdfGraph");
  final Map<String, String> _prefixes = {};
  final List<Triple> _triples = [];

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
