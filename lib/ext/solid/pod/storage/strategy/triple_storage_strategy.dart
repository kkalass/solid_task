import 'package:rdf_core/graph/rdf_graph.dart';
import 'package:rdf_core/graph/rdf_term.dart';
import 'package:rdf_core/graph/triple.dart';

/// Defines strategy for mapping RDF triples to storage locations in a Solid Pod
///
/// Implementations determine how triples are organized into files/resources
/// within a Pod, enabling customized storage patterns while maintaining a consistent API.
abstract interface class TripleStorageStrategy {
  /// Maps triples from a graph to their respective storage locations
  Map<IriTerm, List<Triple>> mapTriplesToStorage(RdfGraph graph);

  /// Determines the appropriate storage location for a specific triple
  IriTerm getStorageIriForTriple(Triple triple);

  /// Identifies storage locations that should be queried based on patterns
  List<IriTerm> getStorageIrisForQuery({
    RdfSubject? subject,
    RdfPredicate? predicate,
    RdfObject? object,
  });
}
