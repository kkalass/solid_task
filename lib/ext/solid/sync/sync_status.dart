import 'package:solid_task/ext/solid/sync/sync_state.dart';

/// Detailed sync status with optional error information
class SyncStatus {
  final SyncState state;
  final String? error;
  final DateTime timestamp;
  final int? itemsUploaded;
  final int? itemsDownloaded;

  SyncStatus({
    required this.state,
    this.error,
    DateTime? timestamp,
    this.itemsUploaded,
    this.itemsDownloaded,
  }) : timestamp = timestamp ?? DateTime.now();

  SyncStatus.idle()
    : state = SyncState.idle,
      error = null,
      itemsUploaded = null,
      itemsDownloaded = null,
      timestamp = DateTime.now();

  SyncStatus.syncing()
    : state = SyncState.syncing,
      error = null,
      itemsUploaded = null,
      itemsDownloaded = null,
      timestamp = DateTime.now();

  SyncStatus.synced({this.itemsUploaded, this.itemsDownloaded})
    : state = SyncState.synced,
      error = null,
      timestamp = DateTime.now();

  SyncStatus.error(String this.error)
    : state = SyncState.error,
      itemsUploaded = null,
      itemsDownloaded = null,
      timestamp = DateTime.now();
}
