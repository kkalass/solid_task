import 'dart:async';

import 'package:solid_task/services/auth/auth_service.dart';
import 'package:solid_task/services/auth/auth_state_provider.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/sync/sync_service.dart';

/// Represents the current status of synchronization
enum SyncState { idle, syncing, synced, error }

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

/// Manages synchronization lifecycle and provides status updates
class SyncManager {
  final SyncService _syncService;
  final AuthService _authService;
  final ContextLogger _logger;

  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();
  StreamSubscription? _authSubscription;
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
  SyncManager(this._syncService, this._authService, this._logger);

  /// Initialize the sync manager and set up auth state listeners
  Future<void> initialize() async {
    _logger.debug('Initializing SyncManager');

    // Subscribe to auth state changes
    _setupAuthListener();

    // If already authenticated, start sync
    final isAuthenticated = _authService.isAuthenticated;
    if (isAuthenticated) {
      _logger.debug('Already authenticated, starting sync');
      await _performSyncIfAuthenticated(isAuthenticated);
    }
  }

  /// Setup listener for authentication state changes
  void _setupAuthListener() {
    // Clean up any existing subscription first
    _authSubscription?.cancel();

    // Subscribe to auth state changes if the service provides them
    if (_authService is AuthStateProvider) {
      final authStateProvider = _authService as AuthStateProvider;
      _authSubscription = authStateProvider.authStateChanges.listen(
        _onAuthStateChanged,
      );
      _logger.debug('Subscribed to auth state changes');
    } else {
      _logger.warning(
        'AuthService does not implement AuthStateProvider, fallback to manual auth state handling',
      );
    }
  }

  /// Handles auth state changes from the auth service
  void _onAuthStateChanged(bool isAuthenticated) {
    _logger.debug('Auth state changed: isAuthenticated=$isAuthenticated');
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
      _logger.debug('Not authenticated, cannot sync');
      _updateStatus(SyncStatus.error('Not authenticated'));
      return SyncResult(success: false, error: 'Not authenticated');
    }

    if (isSyncing) {
      _logger.debug('Sync already in progress, ignoring request');
      return SyncResult(success: false, error: 'Sync already in progress');
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
        _logger.warning('Sync failed: ${result.error}');
        _updateStatus(SyncStatus.error(result.error ?? 'Unknown error'));
      }

      return result;
    } catch (e, stackTrace) {
      _logger.error('Error during sync', e, stackTrace);
      final errorMsg = e.toString();
      _updateStatus(SyncStatus.error(errorMsg));
      return SyncResult(success: false, error: errorMsg);
    }
  }

  /// Start synchronization process
  /// Returns the result of the synchronization
  Future<SyncResult> startSynchronization() async {
    // Cache authentication state to avoid multiple calls
    final isAuthenticated = _authService.isAuthenticated;
    return (await _performSyncIfAuthenticated(isAuthenticated)) ??
        SyncResult(success: false, error: 'Unknown error');
  }

  /// Manually trigger synchronization to remote
  /// For explicit sync requests (usually triggered by UI actions)
  Future<SyncResult> syncToRemote() async {
    if (!_authService.isAuthenticated) {
      return SyncResult(success: false, error: 'Not authenticated');
    }

    if (isSyncing) {
      return SyncResult(success: false, error: 'Sync already in progress');
    }

    _updateStatus(SyncStatus.syncing());
    try {
      final result = await _syncService.syncToRemote();
      if (result.success) {
        _updateStatus(SyncStatus.synced(itemsUploaded: result.itemsUploaded));
      } else {
        _updateStatus(SyncStatus.error(result.error ?? 'Unknown error'));
      }
      return result;
    } catch (e) {
      final errorMsg = e.toString();
      _updateStatus(SyncStatus.error(errorMsg));
      return SyncResult(success: false, error: errorMsg);
    }
  }

  /// Schedule a sync operation to run after a short delay, coalescing multiple requests
  /// This is used when multiple repository changes happen in quick succession
  Future<void> requestSync() async {
    if (!_authService.isAuthenticated || _isDisposed) {
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
    final authenticated = isAuthenticated ?? _authService.isAuthenticated;
    if (authenticated) {
      _logger.debug('Starting periodic sync every 30 seconds');
      _periodicSyncTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _performPeriodicSync(),
      );
    }
  }

  /// Handle periodic sync execution
  Future<void> _performPeriodicSync() async {
    if (!_authService.isAuthenticated || isSyncing || _isDisposed) {
      return;
    }

    _logger.debug('Performing periodic sync');
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
        _updateStatus(SyncStatus.error(result.error ?? 'Unknown error'));
      }
    } catch (e) {
      _logger.error('Error during periodic sync: $e');
      _updateStatus(SyncStatus.error(e.toString()));
    }
  }

  /// Stop periodic synchronization
  void _stopPeriodicSync() {
    if (_periodicSyncTimer != null) {
      _logger.debug('Stopping periodic sync');
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

  /// Handle authentication state changes via manual API call
  /// Only needed when AuthService doesn't support stream of auth state changes
  void handleAuthStateChange(bool isAuthenticated) {
    _onAuthStateChanged(isAuthenticated);
  }

  /// Clean up resources
  void dispose() {
    _isDisposed = true;
    _stopPeriodicSync();
    _authSubscription?.cancel();
    _coalescingTimer?.cancel();
    _syncStatusController.close();
    _logger.debug('SyncManager disposed');
  }
}
