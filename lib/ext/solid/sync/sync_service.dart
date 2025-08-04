/// Result of synchronization operation
class SyncResult {
  /// Whether synchronization was successful
  final bool success;

  /// Number of items downloaded during sync
  final int itemsDownloaded;

  /// Number of items uploaded during sync
  final int itemsUploaded;

  /// Number of items that failed to upload
  final int itemsUploadedFailed;

  /// Error message in case of failure
  final String? errorMessage;

  /// Creates a successful sync result with optional counts
  const SyncResult({
    required this.success,
    this.itemsDownloaded = 0,
    this.itemsUploaded = 0,
    this.itemsUploadedFailed = 0,
    this.errorMessage,
  });

  /// Creates an error sync result
  factory SyncResult.error(String message) =>
      SyncResult(success: false, errorMessage: message);
}

/// Generic synchronization service interface
///
/// This interface defines the operations needed to synchronize data
/// between a local repository and a remote service
abstract interface class SyncService {
  /// Whether the service is connected to the remote
  bool get isConnected;

  /// Identifier of the current user, or null if not authenticated
  String? get userIdentifier;

  /// Synchronize local data to the remote service
  ///
  /// Uploads local changes to the remote service
  /// @return Result of the sync operation
  Future<SyncResult> syncToRemote();

  /// Synchronize data from the remote service
  ///
  /// Downloads remote changes to local storage
  /// @return Result of the sync operation
  Future<SyncResult> syncFromRemote();

  /// Perform a full bidirectional synchronization
  ///
  /// First pulls changes from remote, then pushes local changes
  /// @return Result of the sync operation
  Future<SyncResult> fullSync();

  /// Start periodic synchronization with the given interval
  ///
  /// @param interval Time interval between synchronizations
  void startPeriodicSync(Duration interval);

  /// Stop periodic synchronization
  void stopPeriodicSync();

  /// Clean up resources used by this service
  void dispose();
}
