import 'package:flutter/widgets.dart';

/// Wrapper for the static methods of the solid_auth package to improve testability.
abstract interface class SolidAuthWrapper {
  /// Gets the OIDC issuer URI from a user input.
  Future<String> getIssuer(String input);

  /// Authenticates the user with the OIDC provider.
  Future<Map<dynamic, dynamic>> authenticate(
    Uri issuerUri,
    List<String> scopes,
    BuildContext context,
  );

  /// Logs the user out from the OIDC provider.
  Future<bool> logout(String logoutUrl);

  /// Generates a DPoP token for authentication.
  String genDpopToken(
    String url,
    dynamic rsaKeyPair,
    dynamic publicKeyJwk,
    String method,
  );
}
