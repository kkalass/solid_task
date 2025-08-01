import 'package:flutter/widgets.dart';
import 'package:solid_auth/solid_auth.dart';

class AuthResponse {
  final String webId;

  AuthResponse({required this.webId});
}

/// Wrapper for the static methods of the solid_auth package to improve testability.
abstract interface class SolidAuthenticationBackend {
  /// Initializes the authentication backend and attempts to restore any cached session.
  /// Returns true if a valid session was restored, false otherwise.
  Future<bool> initialize();

  /// Checks if there's a current authenticated user without triggering authentication flow.
  /// Returns the WebID if authenticated, null otherwise.
  String? get currentWebId;

  /// Authenticates the user with the OIDC provider.
  /// Only call this if initialize() returned false or currentWebId is null.
  Future<AuthResponse> authenticate(
    String webIdOrIssuerUri,
    List<String> scopes,
    BuildContext context,
  );

  /// Logs the user out from the OIDC provider.
  Future<bool> logout();

  /// Generates a DPoP token for authentication.
  DPoP genDpopToken(String url, String method);
}
