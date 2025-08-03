import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/ext/solid/pod/storage/pod_storage_configuration.dart';
import 'package:solid_task/ext/solid/pod/storage/pod_storage_configuration_provider.dart';
import 'package:solid_task/ext/solid/pod/storage/strategy/triple_storage_strategy.dart';

/// Auth-based provider that derives configuration from authentication state
final class AuthBasedStorageConfigurationProvider
    implements PodStorageConfigurationProvider {
  final SolidAuthState _authState;
  final String? _appFolderRelPath;
  final TripleStorageStrategy _storageStrategy;
  PodStorageConfiguration? _currentConfig;

  /// Creates a provider that derives configuration from authentication state
  ///
  /// Uses the specified storage strategy and optional app folder path
  AuthBasedStorageConfigurationProvider({
    required SolidAuthState authState,
    required TripleStorageStrategy storageStrategy,
    String? appFolderRelPath,
  }) : _authState = authState,
       _appFolderRelPath = appFolderRelPath,
       _storageStrategy = storageStrategy {
    // Initialize with current auth state
    _updateFromAuthState();

    // Listen for auth state changes and update config accordingly
    _authState.authStateChanges.addListener(() => _updateFromAuthState());
  }

  @override
  PodStorageConfiguration? get currentConfiguration => _currentConfig;

  @override
  Future<PodStorageConfiguration?> refreshConfiguration() async {
    _updateFromAuthState();
    return _currentConfig;
  }

  /// Derives configuration from current auth state
  void _updateFromAuthState() {
    final isAuthenticated = _authState.isAuthenticated;
    final podUrl = _authState.currentUser?.podUrl;

    _currentConfig = (isAuthenticated && podUrl != null)
        ? PodStorageConfiguration(
            storageRoot: podUrl,
            appFolderRelPath: _appFolderRelPath,
            storageStrategy: _storageStrategy,
          )
        : null;
  }

  /// Cleans up resources when provider is no longer needed
  void dispose() {
    // No resources to clean up in the simplified implementation
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthBasedStorageConfigurationProvider &&
          runtimeType == other.runtimeType &&
          _authState == other._authState &&
          _appFolderRelPath == other._appFolderRelPath &&
          _storageStrategy == other._storageStrategy;

  @override
  int get hashCode =>
      Object.hash(_authState, _appFolderRelPath, _storageStrategy);
}
