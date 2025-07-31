import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'package:solid_task/config/app_config.dart';
import 'package:solid_task/ext/solid/pod/profile/web_id_profile_loader.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/solid_authentication_backend.dart';
import 'package:solid_auth/solid_auth.dart' as solid_auth;

final _log = Logger("solid_authentication_oidc");

class MyHook<TRequest, TResponse> extends OidcHook<TRequest, TResponse> {
  MyHook({super.modifyRequest, super.modifyExecution, super.modifyResponse});
  /*
   * Tough luck: The execute method is implemented as an extension method
   * by OidcHookExtensions in oidc_core library. It eventually calls
   * itself recursively. I think that the intention was, that OidcHook
   * is supposed to have an execute method like this one, so I implemented it here.
   * 
   * But anyways, extension methods are bound statically during compile time,
   * so this implementation will never be called.
   */
  Future<TResponse> execute({
    required TRequest request,
    required OidcHookExecution<TRequest, TResponse> defaultExecution,
  }) async {
    var modifiedRequest = await modifyRequest(request);
    var response = await modifyExecution(modifiedRequest, defaultExecution);
    return await modifyResponse(response);
  }
}

class SolidAuthenticationOidc implements SolidAuthenticationBackend {
  OidcUserManager? _manager;
  final WebIdProfileLoader _webIdProfileLoader;

  // DPoP key pair management - using solid_auth generated keys
  Map<String, dynamic>? _rsaInfo;

  SolidAuthenticationOidc({required WebIdProfileLoader webIdProfileLoader})
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
    Uri issuerUri,
    List<String> scopes,
    BuildContext context,
  ) async {
    if (_manager != null) {
      await logout();
    }

    Uri wellKnownUri = OidcUtils.getOpenIdConfigWellKnownUri(issuerUri);

    final (
      frontChannelLogoutUri: frontChannelLogoutUri,
      redirectUri: redirectUri,
      postLogoutRedirectUri: postLogoutRedirectUri,
    ) = _computeUris();

    // Use static client ID pointing to our Public Client Identifier Document
    final clientCredentials = OidcClientAuthentication.none(
      clientId: AppConfig.clientId,
    );

    // Generate RSA key pair for DPoP token generation
    final rsaInfo = await solid_auth.genRsaKeyPair();
    _rsaInfo = Map<String, dynamic>.from(rsaInfo);
    _log.info('DPoP RSA key pair generated');

    _log.info('Using Public Client Identifier: ${AppConfig.clientId}');

    _manager = OidcUserManager.lazy(
      discoveryDocumentUri: wellKnownUri,
      clientCredentials: clientCredentials,
      store: OidcDefaultStore(),
      settings: OidcUserManagerSettings(
        // FIXME: enable strict jwt verification?
        //strictJwtVerification: true,
        scope: {'openid', ...scopes, 'webid'}.toList(),
        frontChannelLogoutUri: frontChannelLogoutUri,
        redirectUri: redirectUri,
        postLogoutRedirectUri: postLogoutRedirectUri,
        hooks: OidcUserManagerHooks(
          token: MyHook(
            modifyRequest: (request) {
              print(
                '== OIDC Request ${request.tokenEndpoint}: ${JsonEncoder.withIndent('  ').convert(request.request.toMap())}',
              );

              ///Generate DPoP token using the RSA private key
              DPoP dPopToken = genDpopToken(
                request.tokenEndpoint.toString(),
                "POST",
              );
              if (request.headers != null) {
                for (var e in dPopToken.httpHeaders().entries) {
                  request.headers![e.key] = e.value;
                }
                _log.info(
                  'Request headers after DPoP token: ${request.headers}',
                );
              } else {
                _log.warning('message.headers is null, cannot add DPoP token');
              }

              return Future.value(request);
            },
          ),
        ),
      ),
    );

    await _manager!.init();
    final oidcUser = await _manager!.loginAuthorizationCodeFlow();
    _log.info('Claims: ${oidcUser?.aggregatedClaims}');
    _log.info('Attributes: ${oidcUser?.attributes}');
    _log.info('User Info: ${oidcUser?.userInfo}');
    if (oidcUser == null) {
      throw Exception('OIDC authentication failed: no user returned');
    }

    _log.info('OIDC User authenticated: ${oidcUser.uid ?? 'unknown'}');

    // Extract WebID from the OIDC token using the Solid-OIDC spec methods
    final webId = _extractWebIdFromOidcUser(oidcUser);

    // FIXME: extra security check: retrieve the profile and ensure that the
    // issuer really is allowed by this webID
    return AuthResponse(webId: webId);
  }

  @override
  DPoP genDpopToken(String url, String method) {
    if (_manager?.currentUser?.token.accessToken == null) {
      throw Exception('No access token available for DPoP generation');
    }

    // Generate DPoP key pair if not already created
    if (_rsaInfo == null) {
      // We need to generate the key pair synchronously, but solid_auth.genRsaKeyPair() is async
      // This is a limitation - we should generate keys during authentication
      throw Exception('RSA key pair not generated. Call authenticate first.');
    }

    final rsaKeyPair = _rsaInfo!['rsa'];
    final publicKeyJwk = _rsaInfo!['pubKeyJwk'];

    final dpopToken = solid_auth.genDpopToken(
      url,
      rsaKeyPair,
      publicKeyJwk,
      method,
    );

    // Get the access token from the current user
    final accessToken = _manager!.currentUser!.token.accessToken!;

    return DPoP(dpopToken: dpopToken, accessToken: accessToken);
  }

  @override
  Future<String> getIssuer(String input) async {
    try {
      final profile = await _webIdProfileLoader.load(input);
      return profile.issuers.first;
    } catch (e, stackTrace) {
      // apparently not a WebID, return the input as is - its probably the issuer URL
      _log.info(
        'Input is not a WebID, returning as issuer URI: $input',
        e,
        stackTrace,
      );
      return input;
    }
  }

  @override
  Future<bool> logout() async {
    await _manager?.logout();
    await _manager?.dispose();
    _manager = null;
    return true;
  }

  /// Extracts the WebID URI from the OIDC user according to the Solid-OIDC specification.
  ///
  /// The spec defines three methods in order of preference:
  /// 1. Custom 'webid' claim in the ID token
  /// 2. 'sub' claim contains a valid HTTP(S) URI
  /// 3. UserInfo request + 'website' claim
  String _extractWebIdFromOidcUser(OidcUser oidcUser) {
    // Method 1: Check for custom 'webid' claim in ID token
    final webidClaim = oidcUser.claims['webid'];
    if (webidClaim != null &&
        webidClaim is String &&
        _isValidHttpUri(webidClaim)) {
      _log.fine('WebID extracted from webid claim: $webidClaim');
      return webidClaim;
    }

    // Method 2: Check if 'sub' claim contains a valid HTTP(S) URI
    final subClaim = oidcUser.claims.subject;
    if (subClaim != null && _isValidHttpUri(subClaim)) {
      _log.fine('WebID extracted from sub claim: $subClaim');
      return subClaim;
    }

    // Method 3: Check userInfo for 'website' claim
    final websiteClaim = oidcUser.userInfo['website'];
    if (websiteClaim != null &&
        websiteClaim is String &&
        _isValidHttpUri(websiteClaim)) {
      _log.fine('WebID extracted from website claim: $websiteClaim');
      return websiteClaim;
    }

    // If no WebID found, throw an exception
    throw Exception(
      'No valid WebID found in OIDC token. '
      'Checked webid claim, sub claim, and website claim. '
      'The OIDC provider must support Solid-OIDC specification.',
    );
  }

  /// Validates if a string is a valid HTTP or HTTPS URI.
  bool _isValidHttpUri(String uriString) {
    try {
      final uri = Uri.parse(uriString);
      return (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
