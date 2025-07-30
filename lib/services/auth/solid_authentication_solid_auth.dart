import 'package:flutter/widgets.dart';
import 'package:solid_auth/solid_auth.dart' as solid_auth;
import 'package:solid_task/ext/solid_flutter/auth/integration/solid_authentication_backend.dart';

/// Wrapper for the static methods of the solid_auth package to improve testability.
class SolidAuthWrapperImpl implements SolidAuthenticationBackend {
  /// Gets the OIDC issuer URI from a user input.
  @override
  Future<String> getIssuer(String input) async {
    return solid_auth.getIssuer(input);
  }

  /// Authenticates the user with the OIDC provider.
  @override
  Future<Map<dynamic, dynamic>> authenticate(
    Uri issuerUri,
    List<String> scopes,
    BuildContext context,
  ) async {
    return solid_auth.authenticate(issuerUri, scopes, context);
  }

  /// Logs the user out from the OIDC provider.
  @override
  Future<bool> logout(String logoutUrl) async {
    return solid_auth.logout(logoutUrl);
  }

  /// Generates a DPoP token for authentication.
  @override
  String genDpopToken(
    String url,
    dynamic rsaKeyPair,
    dynamic publicKeyJwk,
    String method,
  ) {
    return solid_auth.genDpopToken(url, rsaKeyPair, publicKeyJwk, method);
  }
}
