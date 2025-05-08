import 'package:rdf_core/rdf_core.dart';
import 'package:solid_task/ext/solid/pod/storage/strategy/triple_storage_strategy.dart';

/// Default implementation that organizes triples by subject IRI document
///
/// Triples are stored in the document specified by their subject IRI without the fragment.
/// Subjects with blank nodes are stored in a special "orphaned" resource.
final class DefaultTripleStorageStrategy implements TripleStorageStrategy {
  const DefaultTripleStorageStrategy();

  @override
  Map<IriTerm, List<Triple>> mapTriplesToStorage(RdfGraph graph) {
    final result = <IriTerm, List<Triple>>{};

    for (final triple in graph.triples) {
      final storageIri = getStorageIriForTriple(triple);
      result.putIfAbsent(storageIri, () => []).add(triple);
    }

    return result;
  }

  @override
  IriTerm getStorageIriForTriple(Triple triple) {
    final subject = triple.subject;
    if (subject is IriTerm) {
      return _deriveStorageIri(subject);
    }

    return IriTerm('tag:orphaned');
  }

  @override
  List<IriTerm> getStorageIrisForQuery({
    RdfSubject? subject,
    RdfPredicate? predicate,
    RdfObject? object,
  }) {
    if (subject != null && subject is IriTerm) {
      return [_deriveStorageIri(subject)];
    }

    // Without specific subject information, we can't narrow down
    return const []; // Empty means "search everywhere" for implementations
  }

  /// Extracts document URL from an IRI by removing fragment component
  IriTerm _deriveStorageIri(IriTerm term) {
    final iri = term.iri;
    if (iri.startsWith('http://') || iri.startsWith('https://')) {
      final fragmentIndex = iri.indexOf('#');
      if (fragmentIndex != -1) {
        return IriTerm(iri.substring(0, fragmentIndex));
      }
    }
    return term;
  }
}
