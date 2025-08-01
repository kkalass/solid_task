import 'dart:convert';
import 'package:fast_rsa/fast_rsa.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:oidc/oidc.dart';
import 'package:solid_auth/solid_auth.dart' as solid_auth;
import 'package:solid_task/config/app_config.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/solid_authentication_backend.dart';

final _log = Logger("solid_authentication_oidc");

Future<List<Uri>> _getIssuersDefault(String webIdOrIssuer) async {
  try {
    return [Uri.parse(await solid_auth.getIssuer(webIdOrIssuer))];
  } catch (e) {
    // If loading the profile fails, return the input as is
    return [Uri.parse(webIdOrIssuer)];
  }
}

class _RsaInfo {
  final String pubKey;
  final String privKey;
  final dynamic pubKeyJwk;

  _RsaInfo({
    required this.pubKey,
    required this.privKey,
    required this.pubKeyJwk,
  });
}

class SolidOidcUserManagerSettings {
  ///
  const SolidOidcUserManagerSettings({
    required this.redirectUri,
    this.uiLocales,
    this.extraTokenHeaders,
    this.extraScopes = defaultScopes,
    this.prompt = const [],
    this.display,
    this.acrValues,
    this.maxAge,
    this.extraAuthenticationParameters,
    this.expiryTolerance = const Duration(minutes: 1),
    this.extraTokenParameters,
    this.postLogoutRedirectUri,
    this.options,
    this.frontChannelLogoutUri,
    this.userInfoSettings = const OidcUserInfoSettings(),
    this.frontChannelRequestListeningOptions =
        const OidcFrontChannelRequestListeningOptions(),
    this.refreshBefore = defaultRefreshBefore,
    this.strictJwtVerification = false,
    this.getExpiresIn,
    this.sessionManagementSettings = const OidcSessionManagementSettings(),
    this.getIdToken,
    this.supportOfflineAuth = false,
    this.hooks,
    this.extraRevocationParameters,
    this.extraRevocationHeaders,
    this.getIssuers = _getIssuersDefault,
  });

  /// The default scopes
  static const defaultScopes = ['openid', 'webid', 'offline_access'];

  /// Settings to control using the user_info endpoint.
  final OidcUserInfoSettings userInfoSettings;

  /// whether JWTs are strictly verified.
  ///
  /// If set to true, the library will throw an exception if a JWT is invalid.
  final bool strictJwtVerification;

  /// Whether to support offline authentication or not.
  ///
  /// When this option is enabled, expired tokens will NOT be removed if the
  /// server can't be contacted
  ///
  /// This parameter is disabled by default due to security concerns.
  final bool supportOfflineAuth;

  /// see [OidcAuthorizeRequest.redirectUri].
  final Uri redirectUri;

  /// see [OidcEndSessionRequest.postLogoutRedirectUri].
  final Uri? postLogoutRedirectUri;

  /// the uri of the front channel logout flow.
  /// this Uri MUST be registered with the OP first.
  /// the OP will call this Uri when it wants to logout the user.
  final Uri? frontChannelLogoutUri;

  /// The options to use when listening to platform channels.
  ///
  /// [frontChannelLogoutUri] must be set for this to work.
  final OidcFrontChannelRequestListeningOptions
  frontChannelRequestListeningOptions;

  /// see [OidcAuthorizeRequest.scope].
  final List<String> extraScopes;

  /// see [OidcAuthorizeRequest.prompt].
  final List<String> prompt;

  /// see [OidcAuthorizeRequest.display].
  final String? display;

  /// see [OidcAuthorizeRequest.uiLocales].
  final List<String>? uiLocales;

  /// see [OidcAuthorizeRequest.acrValues].
  final List<String>? acrValues;

  /// see [OidcAuthorizeRequest.maxAge]
  final Duration? maxAge;

  /// see [OidcAuthorizeRequest.extra]
  final Map<String, dynamic>? extraAuthenticationParameters;

  /// see [OidcTokenRequest.extra]
  final Map<String, String>? extraTokenHeaders;

  /// see [OidcTokenRequest.extra]
  final Map<String, dynamic>? extraTokenParameters;

  /// see [OidcRevocationRequest.extra]
  final Map<String, dynamic>? extraRevocationParameters;

  /// Extra headers to send with the revocation request.
  final Map<String, String>? extraRevocationHeaders;

  /// see [OidcIdTokenVerificationOptions.expiryTolerance].
  final Duration expiryTolerance;

  /// Settings related to the session management spec.
  final OidcSessionManagementSettings sessionManagementSettings;

  /// How early the token gets refreshed.
  ///
  /// for example:
  ///
  /// - if `Duration.zero` is returned, the token gets refreshed once it's expired.
  /// - (default) if `Duration(minutes: 1)` is returned, it will refresh the token 1 minute before it expires.
  /// - if `null` is returned, automatic refresh is disabled.
  final OidcRefreshBeforeCallback? refreshBefore;

  /// overrides a token's expires_in value.
  final Duration? Function(OidcTokenResponse tokenResponse)? getExpiresIn;

  /// pass this function to control how a webIdOrIssuer is resoled to the issuer URI.
  final Future<List<Uri>> Function(String webIdOrIssuer) getIssuers;

  /// pass this function to control how an `id_token` is fetched from a
  /// token response.
  ///
  /// This can be used to trick the user manager into using a JWT `access_token`
  /// as an `id_token` for example.
  final Future<String?> Function(OidcToken token)? getIdToken;

  /// platform-specific options.
  final OidcPlatformSpecificOptions? options;

  /// Customized hooks to modify the user manager behavior.
  final OidcUserManagerHooks? hooks;
}

class SolidOidcUserManager {
  Uri? _issuerUri;
  OidcUserManager? _manager;

  /// The WebID or issuer URL.
  final String _webIdOrIssuer;

  /// The store responsible for setting/getting cached values.
  final OidcStore store;

  final String? _id;

  /// The http client to use when sending requests
  final http.Client? _httpClient;

  /// The id_token verification options.
  final JsonWebKeyStore? _keyStore;
  final SolidOidcUserManagerSettings _settings;

  // DPoP key pair management - using solid_auth generated keys
  _RsaInfo? _rsaInfo;

  String? _currentWebId;

  // Storage keys for persisting SOLID-specific data
  static const String _rsaInfoKey = 'solid_rsa_info';

  SolidOidcUserManager({
    required String webIdOrIssuer,
    required this.store,
    required SolidOidcUserManagerSettings settings,
    String? id,
    http.Client? httpClient,
    JsonWebKeyStore? keyStore,
  }) : _settings = settings,
       _webIdOrIssuer = webIdOrIssuer,
       _id = id,
       _keyStore = keyStore,
       _httpClient = httpClient;

  /// The current authenticated user, if any
  OidcUser? get currentUser => _manager?.currentUser;
  String? get currentWebId => _currentWebId;

  Future<void> init() async {
    if (_manager != null) {
      await logout();
    }

    // Try to restore persisted RSA info first
    await _loadPersistedRsaInfo();

    final issuerUris = await _settings.getIssuers(_webIdOrIssuer);
    _issuerUri = issuerUris.first;
    Uri wellKnownUri = OidcUtils.getOpenIdConfigWellKnownUri(_issuerUri!);

    // Use static client ID pointing to our Public Client Identifier Document
    final clientCredentials = OidcClientAuthentication.none(
      clientId: AppConfig.clientId,
    );

    // Generate RSA key pair for DPoP token generation if not already available
    if (_rsaInfo == null) {
      final rsaInfo = await solid_auth.genRsaKeyPair();
      final rsa = rsaInfo['rsa'] as KeyPair;
      _rsaInfo = _RsaInfo(
        pubKey: rsa.publicKey,
        privKey: rsa.privateKey,
        pubKeyJwk: rsaInfo['pubKeyJwk'],
      );
      await _persistRsaInfo();
      _log.info('DPoP RSA key pair generated and persisted');
    } else {
      _log.info('DPoP RSA key pair restored from storage');
    }

    _log.info('Using Public Client Identifier: ${AppConfig.clientId}');
    final hooks = _settings.hooks ?? OidcUserManagerHooks();
    final dpopHookTokenHook = OidcHook<OidcTokenHookRequest, OidcTokenResponse>(
      modifyRequest: (request) {
        ///Generate DPoP token using the RSA private key
        String dPopToken = _genDpopToken(
          request.tokenEndpoint.toString(),
          "POST",
        );

        request.headers!['DPoP'] = dPopToken;

        return Future.value(request);
      },
    );
    hooks.token = OidcHookGroup(
      hooks: [if (hooks.token != null) hooks.token!, dpopHookTokenHook],
      executionHook:
          (hooks.token
              is OidcExecutionHookMixin<
                OidcTokenHookRequest,
                OidcTokenResponse
              >)
          ? hooks.token
                as OidcExecutionHookMixin<
                  OidcTokenHookRequest,
                  OidcTokenResponse
                >
          : dpopHookTokenHook,
    );
    _manager = OidcUserManager.lazy(
      discoveryDocumentUri: wellKnownUri,
      clientCredentials: clientCredentials,
      store: store,
      settings: OidcUserManagerSettings(
        strictJwtVerification: _settings.strictJwtVerification,
        scope: {
          // we are more aggressive with our scopes - those scopes simply
          // are needed for solid-oidc.
          ...SolidOidcUserManagerSettings.defaultScopes,
          ..._settings.extraScopes,
        }.toList(),
        frontChannelLogoutUri: _settings.frontChannelLogoutUri,
        redirectUri: _settings.redirectUri,
        postLogoutRedirectUri: _settings.postLogoutRedirectUri,
        hooks: hooks,
        acrValues: _settings.acrValues,
        display: _settings.display,
        expiryTolerance: _settings.expiryTolerance,
        extraAuthenticationParameters: _settings.extraAuthenticationParameters,
        extraTokenHeaders: _settings.extraTokenHeaders,
        extraTokenParameters: _settings.extraTokenParameters,
        uiLocales: _settings.uiLocales,
        prompt: _settings.prompt,
        maxAge: _settings.maxAge,
        extraRevocationHeaders: _settings.extraRevocationHeaders,
        extraRevocationParameters: _settings.extraRevocationParameters,
        options: _settings.options,
        frontChannelRequestListeningOptions:
            _settings.frontChannelRequestListeningOptions,
        refreshBefore: _settings.refreshBefore,
        getExpiresIn: _settings.getExpiresIn,
        sessionManagementSettings: _settings.sessionManagementSettings,
        getIdToken: _settings.getIdToken,
        supportOfflineAuth: _settings.supportOfflineAuth,
        userInfoSettings: _settings.userInfoSettings,
      ),
      keyStore: _keyStore,
      id: _id,
      httpClient: _httpClient,
    );

    await _manager!.init();
    if (_manager!.currentUser != null) {
      _log.info(
        'SolidOidcUserManager initialized with existing user: ${_manager!.currentUser!.claims.subject}',
      );
      // Extract WebID from the OIDC token using the Solid-OIDC spec methods
      String webId = await _extractAndValidateWebId(_manager!.currentUser!);
      _currentWebId = webId;
    } else {
      _log.info('SolidOidcUserManager initialized without existing user');
    }
  }

  Future<({OidcUser oidcUser, String webId})?>
  loginAuthorizationCodeFlow() async {
    final oidcUser = await _manager!.loginAuthorizationCodeFlow();
    if (oidcUser == null) {
      throw Exception('OIDC authentication failed: no user returned');
    }

    // Extract WebID from the OIDC token using the Solid-OIDC spec methods
    String webId = await _extractAndValidateWebId(oidcUser);
    _currentWebId = webId;
    return (oidcUser: oidcUser, webId: webId);
  }

  Future<String> _extractAndValidateWebId(OidcUser oidcUser) async {
    // Extract WebID from the OIDC token using the Solid-OIDC spec methods
    final webId = _extractWebIdFromOidcUser(oidcUser);

    // extra security check: retrieve the profile and ensure that the
    // issuer really is allowed by this webID
    final issuerUris = (await _settings.getIssuers(
      webId,
    )).map(_normalizeUri).toSet();
    final normalizedIssuerUri = _normalizeUri(_issuerUri!);
    if (!issuerUris.contains(normalizedIssuerUri)) {
      throw Exception(
        'No valid issuer found for WebID: $webId . Expected: $normalizedIssuerUri but got: $issuerUris',
      );
    }
    return webId;
  }

  /// Normalizes a URI by removing trailing slashes and converting to lowercase for comparison.
  Uri _normalizeUri(Uri uri) {
    final pathWithoutTrailingSlash = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;

    return uri.replace(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      path: pathWithoutTrailingSlash,
    );
  }

  String _genDpopToken(String url, String method) {
    if (_rsaInfo == null) {
      throw Exception('RSA key pair not generated. Call authenticate first.');
    }

    final rsaKeyPair = KeyPair(_rsaInfo!.pubKey, _rsaInfo!.privKey);
    final publicKeyJwk = _rsaInfo!.pubKeyJwk;

    return solid_auth.genDpopToken(url, rsaKeyPair, publicKeyJwk, method);
  }

  DPoP genDpopToken(String url, String method) {
    if (_manager?.currentUser?.token.accessToken == null) {
      throw Exception('No access token available for DPoP generation');
    }

    final dpopToken = _genDpopToken(url, method);

    // Get the access token from the current user
    final accessToken = _manager!.currentUser!.token.accessToken!;

    return DPoP(dpopToken: dpopToken, accessToken: accessToken);
  }

  Future<bool> logout() async {
    await _manager?.logout();
    await _manager?.dispose();
    _manager = null;
    _issuerUri = null;

    // Clear persisted RSA key pair info
    _rsaInfo = null;
    await _clearPersistedRsaInfo();

    return true;
  }

  /// Persists the RSA key pair info to the store for session continuity
  Future<void> _persistRsaInfo() async {
    if (_rsaInfo != null) {
      final serializableData = {
        'pubKey': _rsaInfo!.pubKey,
        'privKey': _rsaInfo!.privKey,
        'pubKeyJwk': _rsaInfo!.pubKeyJwk,
      };

      await store.set(
        OidcStoreNamespace.secureTokens,
        key: _rsaInfoKey,
        value: jsonEncode(serializableData),
        managerId: _id,
      );
    }
  }

  /// Loads the RSA key pair info from the store
  Future<void> _loadPersistedRsaInfo() async {
    try {
      final rsaInfoStr = await store.get(
        OidcStoreNamespace.secureTokens,
        key: _rsaInfoKey,
        managerId: _id,
      );
      if (rsaInfoStr != null) {
        final data = Map<String, dynamic>.from(jsonDecode(rsaInfoStr));
        _rsaInfo = _RsaInfo(
          pubKey: data['pubKey'] as String,
          privKey: data['privKey'] as String,
          pubKeyJwk: data['pubKeyJwk'] as String,
        );
      }
    } catch (e) {
      _log.warning('Failed to load persisted RSA info: $e');
    }
  }

  /// Clears the persisted RSA key pair info
  Future<void> _clearPersistedRsaInfo() async {
    try {
      await store.remove(
        OidcStoreNamespace.secureTokens,
        key: _rsaInfoKey,
        managerId: _id,
      );
    } catch (e) {
      _log.warning('Failed to clear persisted RSA info: $e');
    }
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
