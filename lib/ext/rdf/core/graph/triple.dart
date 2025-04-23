import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';

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
class Triple {
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
  Triple(this.subject, this.predicate, this.object);

  @override
  bool operator ==(Object other) {
    return other is Triple &&
        subject == other.subject &&
        predicate == other.predicate &&
        object == other.object;
  }

  @override
  int get hashCode => Object.hash(subject, predicate, object);

  @override
  String toString() => 'Triple($subject, $predicate, $object)';
}
