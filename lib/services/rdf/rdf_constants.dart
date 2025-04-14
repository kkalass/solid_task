import 'package:solid_task/services/rdf/rdf_graph.dart';

/// Groups common RDF and XSD IRIs.
abstract class RdfConstants {
  /// Suppress default constructor.
  RdfConstants._(); // Private constructor prevents instantiation

  /// Common RDF and XSD IRIs used throughout the RDF processing system
  static const langStringIri = IriTerm(
    "http://www.w3.org/1999/02/22-rdf-syntax-ns#langString",
  );
  static const stringIri = IriTerm('http://www.w3.org/2001/XMLSchema#string');

  static const typeIri = IriTerm(
    'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
  );

  /// Base IRI for XMLSchema datatypes
  static const xsdBase = 'http://www.w3.org/2001/XMLSchema#';

  /// Creates an XSD datatype IRI from a local name
  static IriTerm makeXsdIri(String xsdType) {
    return IriTerm('$xsdBase$xsdType');
  }
}
