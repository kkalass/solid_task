import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';

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
