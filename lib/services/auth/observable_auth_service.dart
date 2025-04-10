import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:solid_task/services/auth/auth_service.dart';
import 'package:solid_task/services/auth/auth_state_provider.dart';
import 'package:solid_task/services/logger_service.dart';

/// Decorator for AuthService that provides observable auth state changes
class ObservableAuthService implements AuthService, AuthStateProvider {
  final AuthService _authService;
  final ContextLogger _logger;

  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();
  bool _lastAuthState = false;

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  ObservableAuthService(this._authService, this._logger) {
    _lastAuthState = _authService.isAuthenticated;
  }

  // Forward all AuthService methods but notify listeners when auth state changes

  @override
  bool get isAuthenticated => _authService.isAuthenticated;

  @override
  String? get currentWebId => _authService.currentWebId;

  @override
  String? get podUrl => _authService.podUrl;

  @override
  String? get accessToken => _authService.accessToken;

  @override
  Map<String, dynamic>? get decodedToken => _authService.decodedToken;

  @override
  Map<String, dynamic>? get authData => _authService.authData;

  @override
  Future<List<Map<String, dynamic>>> loadProviders() =>
      _authService.loadProviders();

  @override
  Future<String> getIssuer(String input) => _authService.getIssuer(input);

  @override
  Future<AuthResult> authenticate(
    String issuerUri,
    BuildContext context,
  ) async {
    final result = await _authService.authenticate(issuerUri, context);
    _checkAuthStateChange();
    return result;
  }

  @override
  Future<String?> fetchProfileData(String webId) =>
      _authService.fetchProfileData(webId);

  @override
  Future<String?> getPodUrl(String webId) => _authService.getPodUrl(webId);

  @override
  Future<String> getNewPodUrl() => _authService.getNewPodUrl();

  @override
  Future<void> logout() async {
    await _authService.logout();
    _checkAuthStateChange();
  }

  @override
  String generateDpopToken(String url, String method) =>
      _authService.generateDpopToken(url, method);

  /// Check if auth state has changed and notify listeners if it has
  void _checkAuthStateChange() {
    final currentAuthState = _authService.isAuthenticated;
    if (_lastAuthState != currentAuthState) {
      _logger.debug(
        'Auth state changed from $_lastAuthState to $currentAuthState',
      );
      _lastAuthState = currentAuthState;
      _authStateController.add(currentAuthState);
    }
  }

  /// Dispose resources
  void dispose() {
    _authStateController.close();
  }
}
