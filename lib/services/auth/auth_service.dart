import 'package:flutter/widgets.dart';

/// Authentication result containing all necessary data from a successful login
class AuthResult {
  final String? webId;
  final String? podUrl;
  final String? accessToken;
  final Map<String, dynamic>? decodedToken;
  final Map<String, dynamic>? authData;
  final String? error;

  bool get isSuccess => error == null && webId != null;

  AuthResult({
    this.webId,
    this.podUrl,
    this.accessToken,
    this.decodedToken,
    this.authData,
    this.error,
  });

  AuthResult.error(this.error)
    : webId = null,
      podUrl = null,
      accessToken = null,
      decodedToken = null,
      authData = null;
}

// FIXME KK - is it really good practice to make the current auth states available
// like this in the AuthService? Something feels odd about this API - maybe
// it is, because it is so coupled to SOLID concepts, but the implementation
// is called SOLID while the interface is called AuthService. This is a bit confusing.
//

/// Authentication service interface for SOLID authentication
abstract class AuthService {
  /// Check if user is authenticated
  bool get isAuthenticated;

  /// Get the current user's WebID
  String? get currentWebId;

  /// Get the current user's Pod URL
  String? get podUrl;

  /// Get the current access token
  String? get accessToken;

  /// Get the decoded token data
  Map<String, dynamic>? get decodedToken;

  /// Get the full authentication data
  Map<String, dynamic>? get authData;

  /// Load provider information
  Future<List<Map<String, dynamic>>> loadProviders();

  /// Generate issuer URI from provider URL or WebID
  Future<String> getIssuer(String input);

  /// Authenticate with a SOLID provider
  Future<AuthResult> authenticate(String issuerUri, BuildContext context);

  // FIXME KK - when is this used/needed?
  /// Fetch profile data from WebID
  Future<String?> fetchProfileData(String webId);

  /// Get Pod URL from WebID
  Future<String?> getPodUrl(String webId);

  /// Get URL for obtaining a new SOLID Pod
  Future<String> getNewPodUrl();

  /// Logout from current session
  Future<void> logout();

  /// Generate a DPoP token for authenticated requests
  String generateDpopToken(String url, String method);
}
