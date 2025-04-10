/// Interface for services that can notify about authentication state changes
abstract class AuthStateChangeProvider {
  /// Stream of authentication state changes
  /// Emits true when the user is authenticated, false otherwise
  Stream<bool> get authStateChanges;
}
