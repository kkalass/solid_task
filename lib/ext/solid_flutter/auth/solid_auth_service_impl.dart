import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:solid_task/ext/solid/auth/interfaces/auth_state_change_provider.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_provider_service.dart';
import 'package:solid_task/ext/solid/auth/models/auth_result.dart';
import 'package:solid_task/ext/solid/auth/models/auth_token.dart';
import 'package:solid_task/ext/solid/auth/models/user_identity.dart';
import 'package:solid_task/ext/solid/pod/profile/default_solid_profile_parser.dart';
import 'package:solid_task/ext/solid/pod/profile/solid_profile_parser.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/jwt_decoder_wrapper.dart';
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
  final JwtDecoderWrapper _jwtDecoder;
  final SolidAuthenticationBackend _authBackend;
  final SolidProfileParser _profileParser;

  // Auth state
  String? _currentWebId;
  String? _podUrl;
  String? _accessToken;
  Map<String, dynamic>? _decodedToken;
  Map<String, dynamic>? _authData;

  // Authentication state stream controller
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  // Storage keys
  static const String _webIdKey = 'solid_webid';
  static const String _podUrlKey = 'solid_pod_url';
  static const String _accessTokenKey = 'solid_access_token';
  static const String _authDataKey = 'solid_auth_data';

  // Initialization tracking
  late final Future<void> _initializationFuture;

  @override
  bool get isAuthenticated => _currentWebId != null && _accessToken != null;

  @override
  UserIdentity? get currentUser {
    if (!isAuthenticated) return null;
    return UserIdentity(webId: _currentWebId!, podUrl: _podUrl);
  }

  @override
  AuthToken? get authToken {
    if (!isAuthenticated || _accessToken == null) return null;

    DateTime? expiresAt;
    if (_decodedToken != null && _decodedToken!.containsKey('exp')) {
      final expiryTimestamp = _decodedToken!['exp'];
      if (expiryTimestamp is int) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp * 1000);
      }
    }

    return AuthToken(
      accessToken: _accessToken!,
      decodedData: _decodedToken,
      expiresAt: expiresAt,
    );
  }

  @override
  Map<String, dynamic>? get authData => _authData;

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  // Private constructor with dependency injection
  SolidAuthServiceImpl._({
    required http.Client client,
    FlutterSecureStorage? secureStorage,
    required JwtDecoderWrapper jwtDecoder,
    required SolidAuthenticationBackend authBackend,
    SolidProfileParser? profileParser,
  }) : _client = client,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _jwtDecoder = jwtDecoder,
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
    required JwtDecoderWrapper jwtDecoder,
    required SolidAuthenticationBackend solidAuth,
    FlutterSecureStorage? secureStorage,
    SolidProfileParser? profileParser,
  }) async {
    final service = SolidAuthServiceImpl._(
      client: client,
      secureStorage: secureStorage,
      jwtDecoder: jwtDecoder,
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
      if (_accessToken != null) {
        await _secureStorage.write(key: _accessTokenKey, value: _accessToken);
      }
      if (_authData != null) {
        await _secureStorage.write(
          key: _authDataKey,
          value: json.encode(_authData),
        );
      }
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
      _accessToken = null;
      _decodedToken = null;
      _authData = null;
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
  Future<String> getIssuer(String input) async {
    return _authBackend.getIssuer(input.trim());
  }

  @override
  Future<AuthResult> authenticate(
    String issuerUri,
    BuildContext context,
  ) async {
    try {
      final List<String> scopes = ['openid', 'profile', 'offline_access'];

      final authData = await _authBackend.authenticate(
        Uri.parse(issuerUri),
        scopes,
        context,
      );

      _accessToken = authData['accessToken'];
      _decodedToken = _jwtDecoder.decode(_accessToken!);
      _currentWebId = _decodedToken!.containsKey('webid')
          ? _decodedToken!['webid']
          : _decodedToken!['sub'];
      _authData = Map<String, dynamic>.from(authData);

      // Get pod URL from WebID
      _podUrl = await resolvePodUrl(_currentWebId!);

      // Save session
      await _saveSession();

      _log.info('Authentication successful: $_currentWebId');

      // Create result objects using our model classes
      final userIdentity = UserIdentity(webId: _currentWebId!, podUrl: _podUrl);

      DateTime? expiresAt;
      if (_decodedToken!.containsKey('exp')) {
        final expiryTimestamp = _decodedToken!['exp'];
        if (expiryTimestamp is int) {
          expiresAt = DateTime.fromMillisecondsSinceEpoch(
            expiryTimestamp * 1000,
          );
        }
      }

      final token = AuthToken(
        accessToken: _accessToken!,
        decodedData: _decodedToken,
        expiresAt: expiresAt,
      );

      // Notify listeners about auth state change
      _notifyAuthStateChange();

      return AuthResult(
        userIdentity: userIdentity,
        token: token,
        authData: _authData,
      );
    } catch (e, stackTrace) {
      _log.severe('Authentication error', e, stackTrace);
      return AuthResult.error(e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      if (_authData != null && _authData!.containsKey('logoutUrl')) {
        await _authBackend.logout(_authData!['logoutUrl']);
      }
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
  String generateDpopToken(String url, String method) {
    try {
      if (!isAuthenticated || _authData == null) {
        throw Exception('Not authenticated');
      }

      var rsaInfo = _authData!['rsaInfo'];
      var rsaKeyPair = rsaInfo['rsa'];
      var publicKeyJwk = rsaInfo['pubKeyJwk'];

      return _authBackend.genDpopToken(url, rsaKeyPair, publicKeyJwk, method);
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
