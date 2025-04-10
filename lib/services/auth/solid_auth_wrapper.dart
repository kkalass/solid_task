import 'package:flutter/widgets.dart';
import 'package:solid_auth/solid_auth.dart' as solid_auth;

/// Wrapper for the static methods of the solid_auth package to improve testability.
class SolidAuth {
  /// Gets the OIDC issuer URI from a user input.
  Future<String> getIssuer(String input) async {
    return solid_auth.getIssuer(input);
  }

  /// Authenticates the user with the OIDC provider.
  Future<Map<dynamic, dynamic>> authenticate(
    Uri issuerUri,
    List<String> scopes,
    BuildContext context,
  ) async {
    return solid_auth.authenticate(issuerUri, scopes, context);
  }

  /// Logs the user out from the OIDC provider.
  Future<bool> logout(String logoutUrl) async {
    return solid_auth.logout(logoutUrl);
  }

  /// Generates a DPoP token for authentication.
  String genDpopToken(
    String url,
    dynamic rsaKeyPair,
    dynamic publicKeyJwk,
    String method,
  ) {
    return solid_auth.genDpopToken(url, rsaKeyPair, publicKeyJwk, method);
  }
}
