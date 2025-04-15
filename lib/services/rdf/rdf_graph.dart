import 'package:equatable/equatable.dart';
import 'package:solid_task/services/rdf/rdf_constants.dart';

/// Hierarchy of RDF terms representing the core data model
/// This is independent of any specific serialization format

/// Base type for all RDF terms
sealed class RdfTerm extends Equatable {
  const RdfTerm();
}

sealed class RdfObject extends RdfTerm {
  const RdfObject();
}

sealed class RdfSubject extends RdfTerm {
  const RdfSubject();
}

sealed class RdfPredicate extends RdfTerm {
  const RdfPredicate();
}

/// IRI (Internationalized Resource Identifier) in RDF
class IriTerm extends RdfTerm implements RdfPredicate, RdfSubject, RdfObject {
  final String iri;

  const IriTerm(this.iri);

  @override
  List<Object?> get props => [iri];

  @override
  bool operator ==(Object other) {
    return other is IriTerm && iri.toLowerCase() == other.iri.toLowerCase();
  }

  @override
  int get hashCode => iri.hashCode;
}

/// BlankNode (anonymous resource) in RDF
class BlankNodeTerm extends RdfTerm implements RdfSubject, RdfObject {
  final String label;

  const BlankNodeTerm(this.label);

  @override
  List<Object?> get props => [label];
}

/// Literal value in RDF
class LiteralTerm extends RdfTerm implements RdfObject {
  final String value;
  final IriTerm datatype;
  final String? language;

  /// Create a literal with optional datatype or language tag
  /// Note: RDF spec requires that a literal with language tag must use rdf:langString datatype
  const LiteralTerm(this.value, {required this.datatype, this.language})
    : assert(
        (language == null) != (datatype == RdfConstants.langStringIri),
        'Language-tagged literals must use rdf:langString datatype, and rdf:langString must have a language tag',
      );

  /// Create a typed literal with XSD datatype
  factory LiteralTerm.typed(String value, String xsdType) {
    return LiteralTerm(value, datatype: XsdConstants.makeIri(xsdType));
  }

  /// Create a string literal
  factory LiteralTerm.string(String value) {
    return LiteralTerm(value, datatype: XsdConstants.stringIri);
  }

  /// Create a language-tagged literal
  factory LiteralTerm.withLanguage(String value, String langTag) {
    return LiteralTerm(
      value,
      datatype: RdfConstants.langStringIri,
      language: langTag,
    );
  }

  @override
  List<Object?> get props => [value, datatype, language];
}

/// Represents an RDF triple.
///
/// A triple consists of three components:
/// - subject: The resource being described (IRI or BlankNode)
/// - predicate: The property or relationship (always an IRI)
/// - object: The value or related resource (IRI, BlankNode, or Literal)
///
/// Example:
/// ```turtle
/// <http://example.com/foo> <http://example.com/bar> "baz" .
/// ```
class Triple extends Equatable {
  /// The subject of the triple, representing the resource being described.
  /// Must be either an IRI or a blank node.
  final RdfSubject subject;

  /// The predicate of the triple, representing the property or relationship.
  /// Must be an IRI.
  final RdfPredicate predicate;

  /// The object of the triple, representing the value or related resource.
  /// Can be an IRI, a blank node, or a literal.
  final RdfObject object;

  /// Creates a new triple with the specified subject, predicate, and object.
  ///
  /// Throws [ArgumentError] if:
  /// - subject is not an IRI or blank node
  /// - predicate is not an IRI
  Triple(this.subject, this.predicate, this.object) {
    // Validate subject
    if (subject is! IriTerm && subject is! BlankNodeTerm) {
      throw ArgumentError('Subject must be an IRI or blank node');
    }

    // Predicate is already constrained by the type system to be an IriTerm
  }

  @override
  List<Object?> get props => [subject, predicate, object];
}

/// Represents an immutable RDF graph with triple pattern matching capabilities
final class RdfGraph {
  /// All triples in this graph
  final List<Triple> _triples;

  /// Creates an immutable RDF graph from a list of triples
  ///
  /// The constructor makes a defensive copy of the provided triples list
  /// to ensure immutability.
  RdfGraph({List<Triple> triples = const []})
    : _triples = List.unmodifiable(List.from(triples));

  /// Creates an RDF graph from a list of triples (factory constructor)
  static RdfGraph fromTriples(List<Triple> triples) =>
      RdfGraph(triples: triples);

  /// Creates a new graph with the specified triple added
  ///
  /// Returns a new RdfGraph instance with all the existing triples plus the new one.
  ///
  /// @param triple The triple to add to the graph
  /// @return A new graph instance with the added triple
  RdfGraph withTriple(Triple triple) {
    final newTriples = List<Triple>.from(_triples)..add(triple);
    return RdfGraph(triples: newTriples);
  }

  /// Creates a new graph with all the specified triples added
  ///
  /// Returns a new RdfGraph instance with all existing and new triples.
  ///
  /// @param triples The triples to add to the graph
  /// @return A new graph instance with the added triples
  RdfGraph withTriples(List<Triple> triples) {
    final newTriples = List<Triple>.from(_triples)..addAll(triples);
    return RdfGraph(triples: newTriples);
  }

  /// Creates a new graph by filtering out triples that match a pattern
  ///
  /// @param subject Optional subject to match
  /// @param predicate Optional predicate to match
  /// @param object Optional object to match
  /// @return A new graph with matching triples removed
  RdfGraph withoutMatching({
    RdfSubject? subject,
    RdfPredicate? predicate,
    RdfObject? object,
  }) {
    final filteredTriples =
        _triples.where((triple) {
          if (subject != null && triple.subject == subject) return false;
          if (predicate != null && triple.predicate == predicate) return false;
          if (object != null && triple.object == object) return false;
          return true;
        }).toList();

    return RdfGraph(triples: filteredTriples);
  }

  /// Find all triples matching the given pattern
  ///
  /// @param subject Optional subject to match
  /// @param predicate Optional predicate to match
  /// @param object Optional object to match
  /// @return List of matching triples (unmodifiable)
  List<Triple> findTriples({
    RdfSubject? subject,
    RdfPredicate? predicate,
    RdfObject? object,
  }) {
    return List.unmodifiable(
      _triples.where((triple) {
        if (subject != null && triple.subject != subject) return false;
        if (predicate != null && triple.predicate != predicate) return false;
        if (object != null && triple.object != object) return false;
        return true;
      }),
    );
  }

  /// Get all objects for a given subject and predicate
  ///
  /// @param subject The subject of the triples to query
  /// @param predicate The predicate of the triples to query
  /// @return List of all object values (unmodifiable)
  List<RdfObject> getObjects(RdfSubject subject, RdfPredicate predicate) {
    return List.unmodifiable(
      findTriples(
        subject: subject,
        predicate: predicate,
      ).map((triple) => triple.object),
    );
  }

  /// Get all subjects with a given predicate and object
  ///
  /// @param predicate The predicate of the triples to query
  /// @param object The object value of the triples to query
  /// @return List of all matching subjects (unmodifiable)
  List<RdfSubject> getSubjects(RdfPredicate predicate, RdfObject object) {
    return List.unmodifiable(
      findTriples(
        predicate: predicate,
        object: object,
      ).map((triple) => triple.subject),
    );
  }

  /// Merges this graph with another, producing a new graph
  ///
  /// @param other The graph to merge with this one
  /// @return A new graph containing all triples from both graphs
  RdfGraph merge(RdfGraph other) {
    return withTriples(other._triples);
  }

  /// Get all triples in the graph
  List<Triple> get triples => _triples;

  /// Number of triples in this graph
  int get size => _triples.length;

  /// Whether this graph contains any triples
  bool get isEmpty => _triples.isEmpty;

  /// Whether this graph contains at least one triple
  bool get isNotEmpty => _triples.isNotEmpty;

  /// We are implementing equals ourselves instead of using equatable,
  /// because we want to compare the sets of triples, not the order
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RdfGraph) return false;

    // Compare triple sets (order doesn't matter in RDF graphs)
    final Set<Triple> thisTriples = _triples.toSet();
    final Set<Triple> otherTriples = other._triples.toSet();
    return thisTriples.length == otherTriples.length &&
        thisTriples.containsAll(otherTriples);
  }

  @override
  int get hashCode => Object.hashAllUnordered(_triples);
}
