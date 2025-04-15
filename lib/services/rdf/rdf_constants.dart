import 'package:solid_task/services/rdf/rdf_graph.dart';

/// Centralized repository of common RDF constants and vocabulary terms.
///
/// This class provides standardized IRIs for RDF and XSD vocabularies,
/// organized in logical namespaces to improve code readability and maintainability.
/// All members are immutable and all IRIs follow W3C specifications.

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

/// XML Schema Definition (XSD) namespace constants
class XsdConstants {
  const XsdConstants._();

  /// Base IRI for XMLSchema datatypes
  static const String namespace = 'http://www.w3.org/2001/XMLSchema#';

  /// IRI for xsd:string datatype
  static const stringIri = IriTerm('${namespace}string');

  /// IRI for xsd:boolean datatype
  static const booleanIri = IriTerm('${namespace}boolean');

  /// IRI for xsd:integer datatype
  static const integerIri = IriTerm('${namespace}integer');

  /// IRI for xsd:decimal datatype
  static const decimalIri = IriTerm('${namespace}decimal');

  /// IRI for xsd:dateTime datatype
  static const dateTimeIri = IriTerm('${namespace}dateTime');

  /// Creates an XSD datatype IRI from a local name
  ///
  /// @param xsdType The local name of the XSD datatype (e.g., "string", "integer")
  /// @return An IriTerm representing the full XSD datatype IRI
  static IriTerm makeIri(String xsdType) => IriTerm('$namespace$xsdType');
}

/// Dublin Core Terms namespace constants
class DcTermsConstants {
  const DcTermsConstants._();

  /// Base IRI for Dublin Core Terms vocabulary
  static const String namespace = 'http://purl.org/dc/terms/';

  /// IRI for dcterms:created property
  static const createdIri = IriTerm('${namespace}created');

  /// IRI for dcterms:creator property
  static const creatorIri = IriTerm('${namespace}creator');

  /// IRI for dcterms:modified property
  static const modifiedIri = IriTerm('${namespace}modified');
}
