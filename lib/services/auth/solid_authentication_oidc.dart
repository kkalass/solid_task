import 'package:flutter/widgets.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/solid_authentication_backend.dart';

class OidcBackend implements SolidAuthenticationBackend {
  @override
  Future<Map> authenticate(
    Uri issuerUri,
    List<String> scopes,
    BuildContext context,
  ) {
    // TODO: implement authenticate
    throw UnimplementedError();
  }

  @override
  String genDpopToken(String url, rsaKeyPair, publicKeyJwk, String method) {
    // TODO: implement genDpopToken
    throw UnimplementedError();
  }

  @override
  Future<String> getIssuer(String input) {
    // TODO: implement getIssuer
    throw UnimplementedError();
  }

  @override
  Future<bool> logout(String logoutUrl) {
    // TODO: implement logout
    throw UnimplementedError();
  }
}
