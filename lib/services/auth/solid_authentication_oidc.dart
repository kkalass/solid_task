import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'package:solid_task/config/app_config.dart';
import 'package:solid_task/ext/solid/pod/profile/web_id_profile_loader.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/solid_authentication_backend.dart';
import 'package:solid_task/services/auth/solid_oidc_user_manager.dart';

final _log = Logger("solid_authentication_oidc");

class SolidAuthenticationOidc implements SolidAuthenticationBackend {
  SolidOidcUserManager? _manager;
  final WebIdProfileLoader? _webIdProfileLoader;
  final OidcStore _store;

  // Storage keys for persisting authentication parameters
  static const String _webIdOrIssuerKey = 'solid_auth_webid_or_issuer';
  static const String _scopesKey = 'solid_auth_scopes';

  SolidAuthenticationOidc({
    WebIdProfileLoader? webIdProfileLoader,
    OidcStore? store,
  }) : _webIdProfileLoader = webIdProfileLoader,
       _store = store ?? OidcDefaultStore();

  @override
  String? get currentWebId => _manager?.currentWebId;

  @override
  Future<bool> initialize() async {
    await _store.init();

    // Try to restore authentication parameters from storage
    final webIdOrIssuer = await _store.get(
      OidcStoreNamespace.secureTokens,
      key: _webIdOrIssuerKey,
    );

    final scopesJson = await _store.get(
      OidcStoreNamespace.secureTokens,
      key: _scopesKey,
    );

    if (webIdOrIssuer != null && scopesJson != null) {
      try {
        final scopes = List<String>.from(jsonDecode(scopesJson));
        _manager = await _createAndInitializeManager(webIdOrIssuer, scopes);

        // Verify the manager actually has a valid session
        if (_manager?.currentUser != null) {
          _log.info(
            'Successfully restored session for webIdOrIssuer: $webIdOrIssuer',
          );
          return true;
        } else {
          _log.info('Stored parameters found but no valid session exists');
          await _clearStoredParameters();
        }
      } catch (e) {
        _log.warning('Failed to restore session with stored parameters: $e');
        await _clearStoredParameters();
      }
    }

    _log.info('No valid session found during initialization');
    return false;
  }

  /// Clears stored authentication parameters
  Future<void> _clearStoredParameters() async {
    await _store.remove(
      OidcStoreNamespace.secureTokens,
      key: _webIdOrIssuerKey,
    );
    await _store.remove(OidcStoreNamespace.secureTokens, key: _scopesKey);
  }

  /// Persists authentication parameters for session restoration
  Future<void> _persistAuthParameters(
    String webIdOrIssuer,
    List<String> scopes,
  ) async {
    await _store.set(
      OidcStoreNamespace.secureTokens,
      key: _webIdOrIssuerKey,
      value: webIdOrIssuer,
    );
    await _store.set(
      OidcStoreNamespace.secureTokens,
      key: _scopesKey,
      value: jsonEncode(scopes),
    );
  }

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
    // Clean up any existing manager
    if (_manager != null) {
      await logout();
    }

    // Create and initialize manager with new parameters
    _manager = await _createAndInitializeManager(webIdOrIssuerUri, scopes);

    // Check if there's already a valid session (from cached tokens)
    if (_manager!.currentUser != null && _manager!.currentWebId != null) {
      final webId = _manager!.currentWebId!;
      // Persist the parameters for future restoration
      await _persistAuthParameters(webIdOrIssuerUri, scopes);

      _log.info('Using restored session for WebID: $webId');
      return AuthResponse(webId: webId);
    }

    // No existing session, perform full authentication flow
    final authResult = await _manager!.loginAuthorizationCodeFlow();
    if (authResult == null) {
      throw Exception('OIDC authentication failed: no user returned');
    }

    final (oidcUser: oidcUser, webId: webId) = authResult;

    // Persist authentication parameters for session restoration
    await _persistAuthParameters(webIdOrIssuerUri, scopes);

    _log.info(
      'OIDC User authenticated: ${oidcUser.uid ?? 'unknown'} for webId: $webId',
    );

    return AuthResponse(webId: webId);
  }

  Future<SolidOidcUserManager> _createAndInitializeManager(
    String webIdOrIssuerUri,
    List<String> scopes,
  ) async {
    final (
      frontChannelLogoutUri: frontChannelLogoutUri,
      redirectUri: redirectUri,
      postLogoutRedirectUri: postLogoutRedirectUri,
    ) = _computeUris();

    var manager = SolidOidcUserManager(
      webIdOrIssuer: webIdOrIssuerUri,
      store: _store,
      settings: SolidOidcUserManagerSettings(
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
    );

    await manager.init();
    return manager;
  }

  @override
  DPoP genDpopToken(String url, String method) {
    return _manager!.genDpopToken(url, method);
  }

  @override
  Future<bool> logout() async {
    final r = await _manager?.logout();
    _manager = null;

    // Clear stored authentication parameters
    await _clearStoredParameters();

    return r ?? true;
  }
}
