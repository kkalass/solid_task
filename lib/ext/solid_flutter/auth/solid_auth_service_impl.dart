import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:solid_task/ext/solid/auth/interfaces/auth_state_change_provider.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_provider_service.dart';
import 'package:solid_task/ext/solid/auth/models/auth_result.dart';
import 'package:solid_task/ext/solid/auth/models/user_identity.dart';
import 'package:solid_task/ext/solid/pod/profile/default_solid_profile_parser.dart';
import 'package:solid_task/ext/solid/pod/profile/solid_profile_parser.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/solid_authentication_backend.dart';

final _log = Logger("solid_flutter");

/// Implementation of the SolidAuthService interface using the SOLID authentication protocol
class SolidAuthServiceImpl
    implements
        SolidAuthState,
        SolidAuthOperations<BuildContext>,
        AuthStateChangeProvider {
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  final SolidAuthenticationBackend _authBackend;
  final SolidProfileParser _profileParser;

  // Auth state
  String? _currentWebId;
  String? _podUrl;

  // Authentication state stream controller
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  // Storage keys
  static const String _webIdKey = 'solid_webid';
  static const String _podUrlKey = 'solid_pod_url';
  /*
  static const String _accessTokenKey = 'solid_access_token';
  static const String _authDataKey = 'solid_auth_data';
  */

  // Initialization tracking
  late final Future<void> _initializationFuture;

  @override
  bool get isAuthenticated => _currentWebId != null;

  @override
  UserIdentity? get currentUser {
    if (!isAuthenticated) return null;
    return UserIdentity(webId: _currentWebId!, podUrl: _podUrl);
  }

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  // Private constructor with dependency injection
  SolidAuthServiceImpl._({
    required http.Client client,
    FlutterSecureStorage? secureStorage,
    required SolidAuthenticationBackend authBackend,
    SolidProfileParser? profileParser,
  }) : _client = client,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _authBackend = authBackend,
       _profileParser = profileParser ?? DefaultSolidProfileParser() {
    _initializationFuture = _initialize();
  }

  // Async initialization
  Future<void> _initialize() async {
    try {
      await _tryRestoreSession();
      _notifyAuthStateChange();
    } catch (e, stackTrace) {
      _log.severe('Error during initialization', e, stackTrace);
    }
  }

  // Factory constructor
  static Future<SolidAuthServiceImpl> create({
    required http.Client client,
    required SolidProviderService providerService,
    required SolidAuthenticationBackend solidAuth,
    FlutterSecureStorage? secureStorage,
    SolidProfileParser? profileParser,
  }) async {
    final service = SolidAuthServiceImpl._(
      client: client,
      secureStorage: secureStorage,
      authBackend: solidAuth,
      profileParser: profileParser,
    );

    await service._initializationFuture;
    return service;
  }

  // Session restoration
  Future<void> _tryRestoreSession() async {
    try {
      _currentWebId = await _secureStorage.read(key: _webIdKey);
      _podUrl = await _secureStorage.read(key: _podUrlKey);
      /*
      _accessToken = await _secureStorage.read(key: _accessTokenKey);

      final authDataStr = await _secureStorage.read(key: _authDataKey);
      if (authDataStr != null) {
        _authData = json.decode(authDataStr);
      }
      

      if (_accessToken != null) {
        try {
          _decodedToken = _jwtDecoder.decode(_accessToken!);

          // Validate token expiry
          if (_decodedToken!.containsKey('exp')) {
            final expiryTimestamp = _decodedToken!['exp'];
            if (expiryTimestamp is int) {
              final expiry = DateTime.fromMillisecondsSinceEpoch(
                expiryTimestamp * 1000,
              );
              if (expiry.isBefore(DateTime.now())) {
                _log.warning('Token has expired, clearing session');
                await _clearSession();
              }
            }
          }
        } catch (e) {
          _log.warning('Invalid access token, clearing session');
          await _clearSession();
        }
      }
      */
      _log.fine('Session restored: ${isAuthenticated ? 'Yes' : 'No'}');
    } catch (e, stackTrace) {
      _log.severe('Error restoring session', e, stackTrace);
      await _clearSession();
    }
  }

  // Session storage
  Future<void> _saveSession() async {
    try {
      if (_currentWebId != null) {
        await _secureStorage.write(key: _webIdKey, value: _currentWebId);
      }
      if (_podUrl != null) {
        await _secureStorage.write(key: _podUrlKey, value: _podUrl);
      }
      /*
      if (_accessToken != null) {
        await _secureStorage.write(key: _accessTokenKey, value: _accessToken);
      }
      if (_authData != null) {
        await _secureStorage.write(
          key: _authDataKey,
          value: json.encode(_authData),
        );
      }
      */
    } catch (e, stackTrace) {
      _log.severe('Error saving session', e, stackTrace);
    }
  }

  // Session cleanup
  Future<void> _clearSession() async {
    try {
      await _secureStorage.deleteAll();
      _currentWebId = null;
      _podUrl = null;
      /*
      _accessToken = null;
      _decodedToken = null;
      _authData = null;
      */
      _notifyAuthStateChange();
    } catch (e, stackTrace) {
      _log.severe('Error clearing session', e, stackTrace);
    }
  }

  // Auth state notification
  void _notifyAuthStateChange() {
    _authStateController.add(isAuthenticated);
  }

  @override
  Future<AuthResult> authenticate(
    String webIdOrIssuerUri,
    BuildContext context,
  ) async {
    try {
      // Include webid scope for Solid-OIDC authentication
      final List<String> scopes = ['openid', 'offline_access', 'webid'];

      final authData = await _authBackend.authenticate(
        webIdOrIssuerUri,
        scopes,
        context,
      );

      _currentWebId = authData.webId;

      // Get pod URL from WebID
      _podUrl = await resolvePodUrl(_currentWebId!);

      // Save session
      await _saveSession();

      _log.info('Authentication successful: $_currentWebId');

      // Create result objects using our model classes
      final userIdentity = UserIdentity(webId: _currentWebId!, podUrl: _podUrl);

      // Notify listeners about auth state change
      _notifyAuthStateChange();

      return AuthResult(userIdentity: userIdentity);
    } catch (e, stackTrace) {
      _log.severe('Authentication error', e, stackTrace);
      return AuthResult.error(e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _authBackend.logout();
    } catch (e, stackTrace) {
      _log.severe('Error during logout', e, stackTrace);
    } finally {
      await _clearSession();
      _notifyAuthStateChange();
    }
  }

  @override
  Future<String?> resolvePodUrl(String webId) async {
    try {
      final response = await _client.get(
        Uri.parse(webId),
        headers: {
          'Accept': 'text/turtle, application/ld+json;q=0.9, */*;q=0.8',
        },
      );

      if (response.statusCode != 200) {
        _log.warning('Failed to fetch profile: ${response.statusCode}');
        return null;
      }

      final contentType = response.headers['content-type'] ?? '';
      final data = response.body;

      return await _profileParser.parseStorageUrl(webId, data, contentType);
    } catch (e, stackTrace) {
      _log.severe('Error fetching pod URL', e, stackTrace);
      return null;
    }
  }

  @override
  DPoP generateDpopToken(String url, String method) {
    try {
      if (!isAuthenticated) {
        throw Exception('Not authenticated');
      }

      return _authBackend.genDpopToken(url, method);
    } catch (e, stackTrace) {
      _log.severe('Error generating DPoP token', e, stackTrace);
      throw Exception('Failed to generate DPoP token: $e');
    }
  }

  /// Disposes resources when the service is no longer needed
  void dispose() {
    _authStateController.close();
  }
}
