import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';

/// Centralized repository of common RDF constants and vocabulary terms.
///

/// RDF core namespace constants
class RdfConstants {
  const RdfConstants._();

  /// Base IRI for RDF vocabulary
  static const String namespace = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#';

  /// IRI for rdf:type predicate
  static const typeIri = IriTerm('${namespace}type');

  /// IRI for rdf:langString datatype
  static const langStringIri = IriTerm('${namespace}langString');

  /// IRI for rdf:Property
  static const propertyIri = IriTerm('${namespace}Property');

  /// IRI for rdf:Statement
  static const statementIri = IriTerm('${namespace}Statement');
}
