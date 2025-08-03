import 'dart:async';

import 'package:logging/logging.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/ext/solid/sync/sync_service.dart';
import 'package:solid_task/ext/solid/sync/sync_state.dart';
import 'package:solid_task/ext/solid/sync/sync_status.dart';

final _logger = Logger("solid.sync");

/// Manages automatic synchronization based on authentication state
class SyncManager {
  final SyncService _syncService;
  final SolidAuthState _authState;

  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();

  Timer? _periodicSyncTimer;
  Timer? _coalescingTimer;
  bool _isDisposed = false;

  /// Stream of sync status updates that UI components can listen to
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// Current sync status
  SyncStatus _currentStatus = SyncStatus.idle();
  SyncStatus get currentStatus => _currentStatus;

  /// Whether a sync is currently in progress
  bool get isSyncing => _currentStatus.state == SyncState.syncing;

  /// Whether the last sync failed with an error
  bool get hasError => _currentStatus.state == SyncState.error;

  /// The error message from the last failed sync
  String? get errorMessage => _currentStatus.error;

  /// Creates a new SyncManager that will automatically respond to auth state changes
  SyncManager(this._syncService, this._authState);

  /// Initialize the sync manager and set up auth state listeners
  Future<void> initialize() async {
    _logger.fine('Initializing SyncManager');

    // Subscribe to auth state changes
    _setupAuthListener();

    // If already authenticated, start sync
    final isAuthenticated = _authState.isAuthenticated;
    if (isAuthenticated) {
      _logger.fine('Already authenticated, starting sync');
      await _performSyncIfAuthenticated(isAuthenticated);
    }
  }

  /// Setup listener for authentication state changes
  void _setupAuthListener() {
    // Clean up any existing subscription first
    _authState.authStateChanges.removeListener(_onAuthStateChanged);

    // Subscribe to auth state changes if the service provides them
    _authState.authStateChanges.addListener(_onAuthStateChanged);
    _logger.fine('Subscribed to auth state changes');
  }

  /// Handles auth state changes from the auth service
  void _onAuthStateChanged() {
    final isAuthenticated = _authState.authStateChanges.value;
    _logger.fine('Auth state changed: isAuthenticated=$isAuthenticated');
    if (isAuthenticated) {
      _performSyncIfAuthenticated(true);
    } else {
      stopSynchronization();
    }
  }

  /// Performs sync when we already know the authentication state
  /// Internal method to reduce redundant authentication checks
  Future<SyncResult?> _performSyncIfAuthenticated(bool isAuthenticated) async {
    if (!isAuthenticated) {
      _logger.fine('Not authenticated, cannot sync');
      _updateStatus(SyncStatus.error('Not authenticated'));
      return SyncResult.error('Not authenticated');
    }

    if (isSyncing) {
      _logger.fine('Sync already in progress, ignoring request');
      return SyncResult.error('Sync already in progress');
    }

    _logger.info('Starting synchronization');
    _updateStatus(SyncStatus.syncing());

    try {
      final result = await _syncService.fullSync();

      if (result.success) {
        _logger.info(
          'Sync completed successfully: ${result.itemsUploaded} uploaded, ${result.itemsDownloaded} downloaded',
        );
        _updateStatus(
          SyncStatus.synced(
            itemsUploaded: result.itemsUploaded,
            itemsDownloaded: result.itemsDownloaded,
          ),
        );
        _startPeriodicSync(isAuthenticated);
      } else {
        _logger.warning('Sync failed: ${result.errorMessage}');
        _updateStatus(SyncStatus.error(result.errorMessage ?? 'Unknown error'));
      }

      return result;
    } catch (e, stackTrace) {
      _logger.severe('Error during sync', e, stackTrace);
      final errorMsg = e.toString();
      _updateStatus(SyncStatus.error(errorMsg));
      return SyncResult.error(errorMsg);
    }
  }

  /// Start synchronization process
  /// Returns the result of the synchronization
  Future<SyncResult> startSynchronization() async {
    // Cache authentication state to avoid multiple calls
    final isAuthenticated = _authState.isAuthenticated;
    return (await _performSyncIfAuthenticated(isAuthenticated)) ??
        SyncResult.error('Unknown error');
  }

  /// Manually trigger synchronization to remote
  /// For explicit sync requests (usually triggered by UI actions)
  Future<SyncResult> syncToRemote() async {
    if (!_authState.isAuthenticated) {
      return SyncResult.error('Not authenticated');
    }

    if (isSyncing) {
      return SyncResult.error('Sync already in progress');
    }

    _updateStatus(SyncStatus.syncing());
    try {
      final result = await _syncService.syncToRemote();
      if (result.success) {
        _updateStatus(SyncStatus.synced(itemsUploaded: result.itemsUploaded));
      } else {
        _updateStatus(SyncStatus.error(result.errorMessage ?? 'Unknown error'));
      }
      return result;
    } catch (e) {
      final errorMsg = e.toString();
      _updateStatus(SyncStatus.error(errorMsg));
      return SyncResult.error(errorMsg);
    }
  }

  /// Schedule a sync operation to run after a short delay, coalescing multiple requests
  /// This is used when multiple repository changes happen in quick succession
  Future<void> requestSync() async {
    if (!_authState.isAuthenticated || _isDisposed) {
      return;
    }

    // Cancel any pending sync request
    _coalescingTimer?.cancel();

    // Schedule a new sync after a short delay
    _coalescingTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!_isDisposed && !isSyncing) {
        await syncToRemote();
      }
    });
  }

  /// Start periodic synchronization
  void _startPeriodicSync([bool? isAuthenticated]) {
    _stopPeriodicSync(); // Ensure any existing timer is cancelled

    // Only start periodic sync if authenticated
    final authenticated = isAuthenticated ?? _authState.isAuthenticated;
    if (authenticated) {
      _logger.fine('Starting periodic sync every 30 seconds');
      _periodicSyncTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _performPeriodicSync(),
      );
    }
  }

  /// Handle periodic sync execution
  Future<void> _performPeriodicSync() async {
    if (!_authState.isAuthenticated || isSyncing || _isDisposed) {
      return;
    }

    _logger.fine('Performing periodic sync');
    try {
      final result = await _syncService.fullSync();
      if (result.success) {
        _updateStatus(
          SyncStatus.synced(
            itemsUploaded: result.itemsUploaded,
            itemsDownloaded: result.itemsDownloaded,
          ),
        );
      } else {
        _updateStatus(SyncStatus.error(result.errorMessage ?? 'Unknown error'));
      }
    } catch (e) {
      _logger.severe('Error during periodic sync: $e');
      _updateStatus(SyncStatus.error(e.toString()));
    }
  }

  /// Stop periodic synchronization
  void _stopPeriodicSync() {
    if (_periodicSyncTimer != null) {
      _logger.fine('Stopping periodic sync');
      _periodicSyncTimer!.cancel();
      _periodicSyncTimer = null;
    }
  }

  /// Stop all synchronization activities
  void stopSynchronization() {
    _stopPeriodicSync();
    _coalescingTimer?.cancel();
    _updateStatus(SyncStatus.idle());
  }

  /// Update the current status and notify listeners
  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    if (!_isDisposed && !_syncStatusController.isClosed) {
      _syncStatusController.add(status);
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    _isDisposed = true;
    _stopPeriodicSync();
    _authState.authStateChanges.removeListener(_onAuthStateChanged);
    _coalescingTimer?.cancel();
    _syncStatusController.close();
    _logger.fine('SyncManager disposed');
  }
}
