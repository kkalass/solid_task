import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:solid_task/services/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/sync/sync_service.dart';
import 'package:synchronized/synchronized.dart';

/// Implementation of SyncService for SOLID pods
class SolidSyncService implements SyncService {
  final ItemRepository _repository;
  final SolidAuthState _solidAuthState;
  final SolidAuthOperations _solidAuthOperations;
  final http.Client _client;
  final ContextLogger _logger;

  // Periodic sync
  Timer? _syncTimer;
  final Lock _syncLock = Lock();

  // File path constants
  static const String _todosFileName = 'todos.json';

  SolidSyncService({
    required ItemRepository repository,
    required SolidAuthState authState,
    required SolidAuthOperations authOperations,
    required ContextLogger logger,
    required http.Client client,
  }) : _repository = repository,
       _solidAuthState = authState,
       _solidAuthOperations = authOperations,
       _logger = logger,
       _client = client;

  @override
  bool get isConnected => _solidAuthState.isAuthenticated;

  @override
  String? get userIdentifier => _solidAuthState.currentUser?.webId;

  // FIXME KK - is it a good idea to store everything in a single file? Or should we rather store one item per file?
  String? get _dataUrl {
    final podUrl = _solidAuthState.currentUser?.podUrl;
    if (podUrl == null) return null;
    return '$podUrl$_todosFileName';
  }

  @override
  Future<SyncResult> syncToRemote() async {
    if (!isConnected) {
      return SyncResult.error('Not connected to SOLID pod');
    }

    final dataUrl = _dataUrl;
    if (dataUrl == null) {
      return SyncResult.error('Pod URL not available');
    }

    try {
      _logger.debug('Syncing to pod at $dataUrl');

      // FIXME KK - this does a full sync of all items everytime - is this smart?
      // Get all items as JSON
      final items = _repository.exportItems();
      final jsonData = jsonEncode(items);

      // Generate DPoP token for the request
      final dPopToken = _solidAuthOperations.generateDpopToken(dataUrl, 'PUT');

      // Send data to pod
      final response = await _client.put(
        Uri.parse(dataUrl),
        headers: {
          'Accept': '*/*',
          'Authorization': 'DPoP ${_solidAuthState.authToken?.accessToken}',
          'Connection': 'keep-alive',
          'Content-Type': 'application/json',
          'DPoP': dPopToken,
        },
        body: jsonData,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        _logger.error(
          'Failed to sync to pod: ${response.statusCode} - ${response.body}',
        );
        return SyncResult.error(
          'Failed to sync to pod: HTTP ${response.statusCode}',
        );
      }

      _logger.info('Successfully synced ${items.length} items to pod');
      return SyncResult(success: true, itemsUploaded: items.length);
    } catch (e, stackTrace) {
      _logger.error('Error syncing to pod', e, stackTrace);
      return SyncResult.error('Error syncing to pod: $e');
    }
  }

  @override
  Future<SyncResult> syncFromRemote() async {
    if (!isConnected) {
      return SyncResult.error('Not connected to SOLID pod');
    }

    final dataUrl = _dataUrl;
    if (dataUrl == null) {
      return SyncResult.error('Pod URL not available');
    }

    try {
      _logger.debug('Syncing from pod at $dataUrl');

      // Generate DPoP token for the request
      final dPopToken = _solidAuthOperations.generateDpopToken(dataUrl, 'GET');

      // Get data from pod
      final response = await _client.get(
        Uri.parse(dataUrl),
        headers: {
          'Accept': '*/*',
          'Authorization': 'DPoP ${_solidAuthState.authToken?.accessToken}',
          'Connection': 'keep-alive',
          'DPoP': dPopToken,
        },
      );

      if (response.statusCode == 200) {
        // Parse response and update local repository
        final List<dynamic> jsonData = jsonDecode(response.body);
        await _repository.importItems(jsonData);

        _logger.info('Successfully synced ${jsonData.length} items from pod');
        return SyncResult(success: true, itemsDownloaded: jsonData.length);
      } else if (response.statusCode == 404) {
        // File doesn't exist yet, not an error
        _logger.info('No todo file found on pod yet');
        return SyncResult(success: true, itemsDownloaded: 0);
      } else {
        _logger.error(
          'Failed to sync from pod: ${response.statusCode} - ${response.body}',
        );
        return SyncResult.error(
          'Failed to sync from pod: HTTP ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Error syncing from pod', e, stackTrace);
      return SyncResult.error('Error syncing from pod: $e');
    }
  }

  @override
  Future<SyncResult> fullSync() async {
    // Use a lock to prevent multiple syncs running at the same time
    return _syncLock.synchronized(() async {
      if (!isConnected) {
        return SyncResult.error('Not connected to SOLID pod');
      }

      // First sync from remote to get latest changes
      final downloadResult = await syncFromRemote();
      if (!downloadResult.success) {
        return downloadResult;
      }

      // Then sync local changes to remote
      final uploadResult = await syncToRemote();
      if (!uploadResult.success) {
        return uploadResult;
      }

      // Combine results
      return SyncResult(
        success: true,
        itemsDownloaded: downloadResult.itemsDownloaded,
        itemsUploaded: uploadResult.itemsUploaded,
      );
    });
  }

  @override
  void startPeriodicSync(Duration interval) {
    stopPeriodicSync();
    _syncTimer = Timer.periodic(interval, (_) async {
      await fullSync();
    });
    _logger.info('Started periodic sync with interval: $interval');
  }

  @override
  void stopPeriodicSync() {
    if (_syncTimer != null) {
      _syncTimer!.cancel();
      _syncTimer = null;
      _logger.info('Stopped periodic sync');
    }
  }

  @override
  void dispose() {
    stopPeriodicSync();
    _logger.debug('Disposed SolidSyncService');
  }
}
