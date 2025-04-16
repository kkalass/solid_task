import 'package:solid_task/ext/rdf/core/constants/rdf_constants.dart';
import 'package:solid_task/ext/rdf/core/constants/xsd_constants.dart';

/// Hierarchy of RDF terms representing the core data model
/// This is independent of any specific serialization format

/// Base type for all RDF terms
sealed class RdfTerm {
  const RdfTerm();
}

sealed class RdfObject extends RdfTerm {
  const RdfObject();
}

sealed class RdfSubject extends RdfObject {
  const RdfSubject();
}

sealed class RdfPredicate extends RdfTerm {
  const RdfPredicate();
}

/// IRI (Internationalized Resource Identifier) in RDF
class IriTerm extends RdfTerm implements RdfPredicate, RdfSubject {
  final String iri;

  const IriTerm(this.iri);

  @override
  bool operator ==(Object other) {
    return other is IriTerm && iri.toLowerCase() == other.iri.toLowerCase();
  }

  @override
  int get hashCode => iri.hashCode;

  @override
  String toString() => 'IriTerm($iri)';
}

/// BlankNode (anonymous resource) in RDF
class BlankNodeTerm extends RdfTerm implements RdfSubject {
  final String label;

  const BlankNodeTerm(this.label);

  @override
  bool operator ==(Object other) {
    return other is BlankNodeTerm && label == other.label;
  }

  @override
  int get hashCode => label.hashCode;

  @override
  String toString() => 'BlankNodeTerm($label)';
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
  bool operator ==(Object other) {
    return other is LiteralTerm &&
        value == other.value &&
        datatype == other.datatype &&
        language == other.language;
  }

  @override
  int get hashCode => Object.hash(value, datatype, language);

  @override
  String toString() => 'LiteralTerm($value, $datatype, $language)';
}
