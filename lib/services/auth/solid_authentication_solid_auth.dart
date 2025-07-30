import 'package:flutter/widgets.dart';
import 'package:solid_auth/solid_auth.dart' as solid_auth;
import 'package:solid_task/ext/solid_flutter/auth/integration/jwt_decoder_wrapper.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/solid_authentication_backend.dart';

/// Wrapper for the static methods of the solid_auth package to improve testability.
class SolidAuthWrapperImpl implements SolidAuthenticationBackend {
  final JwtDecoderWrapper _jwtDecoder;
  Map<String, dynamic>? _authData;

  SolidAuthWrapperImpl({required JwtDecoderWrapper jwtDecoder})
    : _jwtDecoder = jwtDecoder;

  /// Gets the OIDC issuer URI from a user input.
  @override
  Future<String> getIssuer(String input) async {
    return solid_auth.getIssuer(input);
  }

  /// Authenticates the user with the OIDC provider.
  @override
  Future<AuthResponse> authenticate(
    Uri issuerUri,
    List<String> scopes,
    BuildContext context,
  ) async {
    final authData = await solid_auth.authenticate(issuerUri, scopes, context);
    _authData = Map.unmodifiable(Map<String, dynamic>.from(authData));

    final accessToken = authData['accessToken']!;
    final decodedToken = _jwtDecoder.decode(accessToken);
    final webId = decodedToken.containsKey('webid')
        ? decodedToken['webid']
        : decodedToken['sub'];

    return Future.value(AuthResponse(webId: webId));
  }

  /// Logs the user out from the OIDC provider.
  @override
  Future<bool> logout() async {
    if (_authData != null && _authData!.containsKey('logoutUrl')) {
      await solid_auth.logout(_authData!['logoutUrl']);
    }
    _authData = null;
    return true;
  }

  /// Generates a DPoP token for authentication.
  @override
  DPoP genDpopToken(String url, String method) {
    if (_authData == null) {
      throw Exception('Not authenticated');
    }
    var rsaInfo = _authData!['rsaInfo'];
    var accessToken = _authData!['accessToken'] as String;
    var rsaKeyPair = rsaInfo['rsa'];
    var publicKeyJwk = rsaInfo['pubKeyJwk'];
    final dpopToken = solid_auth.genDpopToken(
      url,
      rsaKeyPair,
      publicKeyJwk,
      method,
    );
    return DPoP(dpopToken: dpopToken, accessToken: accessToken);
  }
}
