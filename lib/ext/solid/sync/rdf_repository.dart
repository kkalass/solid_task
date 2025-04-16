/// Generic repository interface for storing and retrieving data that can be mapped to/from RDF
///
/// This interface enables the sync service to be agnostic of concrete domain types.
/// Implementations will handle the specific domain objects and their conversion.
abstract interface class RdfRepository {
  /// Get all objects from repository that should be synced
  ///
  /// @return List of objects that can be mapped to RDF
  List<Object> getAllSyncableObjects();

  /// Merge objects received from an external source (e.g. a SOLID pod)
  ///
  /// @param objects List of objects that need to be merged into local storage
  /// @return Number of objects that were successfully merged
  Future<int> mergeObjects(List<Object> objects);
}
