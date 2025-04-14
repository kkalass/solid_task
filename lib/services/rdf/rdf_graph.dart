import 'package:equatable/equatable.dart';
import 'package:solid_task/services/rdf/rdf_constants.dart';

/// Hierarchy of RDF terms representing the core data model
/// This is independent of any specific serialization format

/// Base type for all RDF terms
sealed class RdfTerm extends Equatable {
  const RdfTerm();

  /// Accept a visitor for type-safe operations on RDF terms
  T accept<T>(RdfTermVisitor<T> visitor);
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
  T accept<T>(RdfTermVisitor<T> visitor) => visitor.visitIri(this);

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

  @override
  T accept<T>(RdfTermVisitor<T> visitor) => visitor.visitBlankNode(this);
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
    return LiteralTerm(value, datatype: RdfConstants.makeXsdIri(xsdType));
  }

  /// Create a string literal
  factory LiteralTerm.string(String value) {
    return LiteralTerm(value, datatype: RdfConstants.stringIri);
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

  @override
  T accept<T>(RdfTermVisitor<T> visitor) => visitor.visitLiteral(this);
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

/// Represents an RDF graph with prefix handling
class RdfGraph {
  final List<Triple> _triples = [];

  /// Creates an RDF graph from a list of triples
  static RdfGraph fromTriples(List<Triple> triples) {
    final graph = RdfGraph();
    for (final triple in triples) {
      graph.addTriple(triple);
    }
    return graph;
  }

  /// Add a triple to the graph
  void addTriple(Triple triple) {
    _triples.add(triple);
  }

  /// Find all triples matching the given pattern
  List<Triple> findTriples({
    RdfSubject? subject,
    RdfPredicate? predicate,
    RdfObject? object,
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
}

/// Visitor interface for type-safe operations on RDF terms
///
/// This pattern enables adding new operations on RDF terms without
/// modifying the term classes themselves, following the Open/Closed principle.
/// Each visitor implementation provides a specific operation across all term types.
abstract interface class RdfTermVisitor<T> {
  /// Visit an IRI term
  T visitIri(IriTerm iri);

  /// Visit a blank node term
  T visitBlankNode(BlankNodeTerm blankNode);

  /// Visit a literal term
  T visitLiteral(LiteralTerm literal);
}
