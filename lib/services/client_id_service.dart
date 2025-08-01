import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Service responsible for generating and managing the client ID
/// that uniquely identifies this device/installation for CRDT synchronization.
///
/// The client ID is crucial for proper CRDT operation as it:
/// - Uniquely identifies this device in vector clocks
/// - Ensures causality tracking across distributed operations
/// - Persists across app restarts and updates
abstract class ClientIdService {
  /// Gets the client ID for this device/installation.
  ///
  /// This method will:
  /// - Return a cached value if available
  /// - Load from secure storage if not cached
  /// - Generate and persist a new UUID v4 if none exists
  Future<String> getClientId();

  /// Forces regeneration of the client ID.
  ///
  /// **WARNING: Use with extreme caution!**
  /// Regenerating the client ID effectively creates a "new device"
  /// from the CRDT perspective, which can:
  /// - Break vector clock causality chains
  /// - Cause sync conflicts with uncommitted changes
  /// - Lose important historical context
  ///
  /// Valid use cases include:
  /// - Debugging CRDT synchronization issues during development
  /// - Testing multi-device scenarios
  /// - Privacy requirements (similar to resetting advertising ID)
  /// - Recovery from corrupted local state
  /// - Device transfer scenarios
  /// - Customer support troubleshooting
  Future<String> regenerateClientId();
}

/// Default implementation using FlutterSecureStorage for persistence.
///
/// This implementation:
/// - Uses UUID v4 for cryptographically secure random client IDs
/// - Persists the client ID in secure storage to survive app reinstalls
/// - Caches the client ID in memory for performance
/// - Generates a new ID only when none exists or explicitly regenerated
class DefaultClientIdService implements ClientIdService {
  static const String _clientIdKey = 'device_client_id';
  static final Uuid _uuid = Uuid();

  final FlutterSecureStorage _secureStorage;
  String? _cachedClientId;

  DefaultClientIdService({required FlutterSecureStorage secureStorage})
    : _secureStorage = secureStorage;

  @override
  Future<String> getClientId() async {
    // Return cached value if available
    if (_cachedClientId != null) {
      return _cachedClientId!;
    }

    // Try to load from secure storage
    final storedClientId = await _secureStorage.read(key: _clientIdKey);

    if (storedClientId != null && storedClientId.isNotEmpty) {
      _cachedClientId = storedClientId;
      return storedClientId;
    }

    // Generate new client ID if none exists
    return await _generateAndStoreNewClientId();
  }

  @override
  Future<String> regenerateClientId() async {
    return await _generateAndStoreNewClientId();
  }

  /// Generates and stores a new client ID, updating the cache.
  ///
  /// This method is called internally when no client ID exists,
  /// or externally via regenerateClientId() for the specific use cases
  /// documented in the interface method.
  Future<String> _generateAndStoreNewClientId() async {
    // Generate a UUID v4 for the client ID
    final newClientId = _uuid.v4();

    // Store it securely
    await _secureStorage.write(key: _clientIdKey, value: newClientId);

    // Cache it
    _cachedClientId = newClientId;

    return newClientId;
  }
}
