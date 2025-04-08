/// Result of a sync operation
class SyncResult {
  final bool success;
  final String? error;
  final int itemsUploaded;
  final int itemsDownloaded;

  SyncResult({
    required this.success,
    this.error,
    this.itemsUploaded = 0,
    this.itemsDownloaded = 0,
  });

  SyncResult.error(String errorMessage)
    : success = false,
      error = errorMessage,
      itemsUploaded = 0,
      itemsDownloaded = 0;
}

/// Interface for synchronization services
abstract class SyncService {
  /// Whether the sync service is connected to a cloud service
  bool get isConnected;

  /// Get the user identifier for the connected service
  String? get userIdentifier;

  /// Synchronize data from local to remote
  Future<SyncResult> syncToRemote();

  /// Synchronize data from remote to local
  Future<SyncResult> syncFromRemote();

  /// Perform a full two-way sync (download and upload)
  Future<SyncResult> fullSync();

  /// Start periodic background sync
  void startPeriodicSync(Duration interval);

  /// Stop periodic background sync
  void stopPeriodicSync();

  /// Dispose the sync service
  void dispose();
}
