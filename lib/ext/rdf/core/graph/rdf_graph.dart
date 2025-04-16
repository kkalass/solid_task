import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf/core/graph/triple.dart';

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

  /// Groups the triples in the graph by their storage IRI
  ///
  /// For IriTerm subjects:
  /// - HTTP/HTTPS IRIs: groups by the part before the '#' fragment identifier
  /// - Non-HTTP/HTTPS IRIs: groups by the entire IRI
  ///
  /// For BlankNodeTerm subjects: associates with the storage IRI of subjects that reference them.
  /// Follows reference chains to find the ultimate non-blank node subject.
  ///
  /// @return Map where keys are storage IRI terms and values are lists of associated triples
  Map<IriTerm, List<Triple>> groupByStorageIri() {
    final result = <IriTerm, List<Triple>>{};
    final blankNodeMap = <BlankNodeTerm, Set<IriTerm>>{};

    // First pass: Process all IRI subjects and build a reference map for blank nodes
    for (final triple in _triples) {
      final subject = triple.subject;

      if (subject is IriTerm) {
        // Get storage IRI for this subject
        final storageIri = _getStorageIri(subject);

        // Add triple to appropriate group
        result.putIfAbsent(storageIri, () => []).add(triple);

        // If the object is a blank node, record that this subject references it
        if (triple.object is BlankNodeTerm) {
          final blankNode = triple.object as BlankNodeTerm;
          blankNodeMap.putIfAbsent(blankNode, () => {}).add(storageIri);
        }
      } else if (subject is BlankNodeTerm) {
        // If this blank node references other blank nodes, record the relationship
        if (triple.object is BlankNodeTerm) {
          final targetBlankNode = triple.object as BlankNodeTerm;
          blankNodeMap.putIfAbsent(targetBlankNode, () => {});
        }

        // Don't add the triple yet - we'll do that in the second pass
      }
    }

    // Resolve storage IRIs for blank nodes (may require multiple passes)
    bool changed = true;
    while (changed) {
      changed = false;

      for (final triple in _triples) {
        if (triple.subject is BlankNodeTerm) {
          final blankSubject = triple.subject as BlankNodeTerm;
          final referencingIris = blankNodeMap[blankSubject] ?? {};

          if (referencingIris.isNotEmpty) {
            // For simplicity, use the first referencing IRI if there are multiple
            final storageIri = referencingIris.first;

            // Add the triple to this storage IRI's group
            if (!result[storageIri]!.contains(triple)) {
              result.putIfAbsent(storageIri, () => []).add(triple);
              changed = true;
            }

            // If this triple references another blank node, propagate the storage IRI
            if (triple.object is BlankNodeTerm) {
              final targetBlankNode = triple.object as BlankNodeTerm;
              final targetRefs = blankNodeMap.putIfAbsent(
                targetBlankNode,
                () => {},
              );
              if (targetRefs.add(storageIri)) {
                changed = true;
              }
            }
          }
        }
      }
    }

    // Handle any remaining blank node triples that couldn't be associated
    // Put them in a special "orphaned" IRI group
    final orphanedIri = IriTerm('tag:orphaned');
    for (final triple in _triples) {
      if (triple.subject is BlankNodeTerm) {
        bool isOrphan = true;
        for (final list in result.values) {
          if (list.contains(triple)) {
            isOrphan = false;
            break;
          }
        }

        if (isOrphan) {
          result.putIfAbsent(orphanedIri, () => []).add(triple);
        }
      }
    }

    // Return an unmodifiable map with unmodifiable lists to maintain immutability
    return Map.unmodifiable(
      result.map(
        (key, value) => MapEntry(key, List<Triple>.unmodifiable(value)),
      ),
    );
  }

  // Helper method to get the storage IRI for an IRI term
  IriTerm _getStorageIri(IriTerm iriTerm) {
    final iri = iriTerm.iri;

    if (iri.startsWith('http://') || iri.startsWith('https://')) {
      // For HTTP/HTTPS IRIs, use the base before '#' as the key
      final fragmentIndex = iri.indexOf('#');
      final baseIri = fragmentIndex > 0 ? iri.substring(0, fragmentIndex) : iri;
      return IriTerm(baseIri);
    } else {
      // For other schemes, use the entire IRI
      return iriTerm;
    }
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
