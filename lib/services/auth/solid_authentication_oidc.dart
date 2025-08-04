import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'package:solid_auth/solid_auth.dart';
import 'package:solid_task/config/app_config.dart';
import 'package:solid_task/ext/solid/pod/profile/web_id_profile_loader.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/solid_authentication_backend.dart';

final _log = Logger("solid_authentication_oidc");

class SolidAuthenticationOidc implements SolidAuthenticationBackend {
  final SolidAuth _solidAuth;

  SolidAuthenticationOidc({
    WebIdProfileLoader? webIdProfileLoader,
    OidcStore? store,
  }) : _solidAuth = SolidAuth(
         oidcClientId: AppConfig.oidcClientId,
         appUrlScheme: AppConfig.urlScheme,
         frontendRedirectUrl: AppConfig.getWebRedirectUrl(),
         settings: SolidAuthSettings(
           strictJwtVerification: true,
           supportOfflineAuth: true,
           getIssuers: (webIdOrIssuer) async {
             // Use the WebIdProfileLoader to resolve the issuer URI
             if (webIdProfileLoader != null) {
               try {
                 final issuerUris = (await webIdProfileLoader.load(
                   webIdOrIssuer,
                 )).issuers.map((issuer) => Uri.parse(issuer)).toList();
                 return issuerUris.isEmpty
                     ? [Uri.parse(webIdOrIssuer)]
                     : issuerUris;
               } catch (e, stackTrace) {
                 _log.fine(
                   'Failed to load WebID profile for $webIdOrIssuer: $e',
                   e,
                   stackTrace,
                 );
               }
             }
             return [Uri.parse(webIdOrIssuer)];
           },
         ),
         store: store ?? OidcDefaultStore(),
       );

  @override
  String? get currentWebId => _solidAuth.currentWebId;

  @override
  ValueListenable<bool> get isAuthenticatedNotifier =>
      _solidAuth.isAuthenticatedNotifier;

  @override
  Future<bool> initialize() async {
    return await _solidAuth.init();
  }

  @override
  Future<AuthResponse> authenticate(
    String webIdOrIssuerUri,
    List<String> scopes,
    BuildContext context,
  ) async {
    final authResponse = await _solidAuth.authenticate(
      webIdOrIssuerUri,
      scopes: scopes,
    );
    return AuthResponse(webId: authResponse.webId);
  }

  @override
  DPoP genDpopToken(String url, String method) {
    return _solidAuth.genDpopToken(url, method);
  }

  @override
  Future<bool> logout() {
    _solidAuth.logout();
    return Future.value(true);
  }

  @override
  Future<void> dispose() async {
    await _solidAuth.dispose();
  }
}
