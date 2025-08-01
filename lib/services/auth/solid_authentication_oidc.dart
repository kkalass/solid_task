import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'package:solid_task/config/app_config.dart';
import 'package:solid_task/ext/solid/pod/profile/web_id_profile_loader.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/solid_authentication_backend.dart';
import 'package:solid_task/services/auth/solid_oidc_user_manager.dart';

final _log = Logger("solid_authentication_oidc");

class SolidAuthenticationOidc implements SolidAuthenticationBackend {
  SolidOidcUserManager? _manager;
  final WebIdProfileLoader? _webIdProfileLoader;

  SolidAuthenticationOidc({WebIdProfileLoader? webIdProfileLoader})
    : _webIdProfileLoader = webIdProfileLoader;

  ({Uri frontChannelLogoutUri, Uri redirectUri, Uri postLogoutRedirectUri})
  _computeUris() {
    if (kIsWeb) {
      // Web platform uses HTML redirect page
      final htmlPageLink = AppConfig.getWebRedirectUrl();

      return (
        redirectUri: htmlPageLink,
        postLogoutRedirectUri: htmlPageLink,
        frontChannelLogoutUri: htmlPageLink.replace(
          queryParameters: {
            ...htmlPageLink.queryParameters,
            'requestType': 'front-channel-logout',
          },
        ),
      );
    }
    return (
      redirectUri: Uri.parse('${AppConfig.urlScheme}://redirect'),
      postLogoutRedirectUri: Uri.parse('${AppConfig.urlScheme}://logout'),
      frontChannelLogoutUri: Uri.parse('${AppConfig.urlScheme}://logout'),
    );
  }

  @override
  Future<AuthResponse> authenticate(
    String webIdOrIssuerUri,
    List<String> scopes,
    BuildContext context,
  ) async {
    if (_manager != null) {
      await logout();
    }

    final (
      frontChannelLogoutUri: frontChannelLogoutUri,
      redirectUri: redirectUri,
      postLogoutRedirectUri: postLogoutRedirectUri,
    ) = _computeUris();

    _manager = SolidOidcUserManager(
      webIdOrIssuer: webIdOrIssuerUri,
      store: OidcDefaultStore(),
      settings: SolidOidcUserManagerSettings(
        // FIXME enable strict jwt verification?
        //strictJwtVerification: true,
        extraScopes: scopes,
        frontChannelLogoutUri: frontChannelLogoutUri,
        redirectUri: redirectUri,
        postLogoutRedirectUri: postLogoutRedirectUri,
        getIssuers: (webIdOrIssuer) async {
          // Use the WebIdProfileLoader to resolve the issuer URI
          if (_webIdProfileLoader != null) {
            try {
              final issuerUris = (await _webIdProfileLoader.load(
                webIdOrIssuer,
              )).issuers.map((issuer) => Uri.parse(issuer)).toList();
              return issuerUris.isEmpty
                  ? [Uri.parse(webIdOrIssuer)]
                  : issuerUris;
            } catch (e) {
              _log.fine('Failed to load WebID profile for $webIdOrIssuer: $e');
            }
          }
          return [Uri.parse(webIdOrIssuer)];
        },
      ),
    );

    await _manager!.init();
    final authResult = await _manager!.loginAuthorizationCodeFlow();
    switch (authResult) {
      case (oidcUser: var oidcUser, webId: var webId):
        //_log.info('Claims: ${oidcUser.aggregatedClaims}');
        //_log.info('Attributes: ${oidcUser.attributes}');
        //_log.info('User Info: ${oidcUser.userInfo}');

        _log.info(
          'OIDC User authenticated: ${oidcUser.uid ?? 'unknown'} for webId: $webId',
        );

        return AuthResponse(webId: webId);
      case null:
        throw Exception('OIDC authentication failed: no user returned');
    }
  }

  @override
  DPoP genDpopToken(String url, String method) {
    return _manager!.genDpopToken(url, method);
  }

  @override
  Future<bool> logout() async {
    final r = await _manager?.logout();
    _manager = null;
    return r ?? true;
  }
}
