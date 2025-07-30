import 'package:flutter/widgets.dart';

class AuthResponse {
  final String webId;

  AuthResponse({required this.webId});
}

class DPoP {
  final String dpopToken;
  final String accessToken;

  DPoP({required this.dpopToken, required this.accessToken});

  Map<String, String> httpHeaders() => {
    'Authorization': 'DPoP $accessToken',
    'DPoP': dpopToken,
  };
}

/// Wrapper for the static methods of the solid_auth package to improve testability.
abstract interface class SolidAuthenticationBackend {
  /// Gets the OIDC issuer URI from a user input.
  Future<String> getIssuer(String input);

  /// Authenticates the user with the OIDC provider.
  Future<AuthResponse> authenticate(
    Uri issuerUri,
    List<String> scopes,
    BuildContext context,
  );

  /// Logs the user out from the OIDC provider.
  Future<bool> logout();

  /// Generates a DPoP token for authentication.
  DPoP genDpopToken(String url, String method);
}
