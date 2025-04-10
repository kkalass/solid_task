import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:solid_task/models/auth/auth_result.dart';
import 'package:solid_task/models/auth/auth_token.dart';
import 'package:solid_task/models/auth/user_identity.dart';
import 'package:solid_task/services/auth/interfaces/auth_state_change_provider.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/services/auth/interfaces/solid_provider_service.dart';
import 'package:solid_task/services/auth/jwt_decoder_wrapper.dart';
import 'package:solid_task/services/auth/solid_auth_wrapper.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/rdf_parser.dart';
import 'package:solid_task/services/solid/solid_profile_parser.dart';

/// Implementation of the SolidAuthService interface using the SOLID authentication protocol
class SolidAuthServiceImpl
    implements SolidAuthState, SolidAuthOperations, AuthStateChangeProvider {
  final ContextLogger _logger;
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  final JwtDecoderWrapper _jwtDecoder;
  final SolidAuth _solidAuth;
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
    required LoggerService loggerService,
    required http.Client client,
    FlutterSecureStorage? secureStorage,
    JwtDecoderWrapper? jwtDecoder,
    SolidAuth? solidAuth,
    SolidProfileParser? profileParser,
  }) : _logger = loggerService.createLogger('SolidAuthServiceImpl'),
       _client = client,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _jwtDecoder = jwtDecoder ?? JwtDecoderWrapper(),
       _solidAuth = solidAuth ?? SolidAuth(),
       _profileParser =
           profileParser ??
           DefaultSolidProfileParser(
             loggerService: loggerService,
             rdfParser: DefaultRdfParser(loggerService: loggerService),
           ) {
    _initializationFuture = _initialize();
  }

  // Async initialization
  Future<void> _initialize() async {
    try {
      await _tryRestoreSession();
      _notifyAuthStateChange();
    } catch (e, stackTrace) {
      _logger.error('Error during initialization', e, stackTrace);
    }
  }

  // Factory constructor
  static Future<SolidAuthServiceImpl> create({
    required LoggerService loggerService,
    required http.Client client,
    required SolidProviderService providerService,
    FlutterSecureStorage? secureStorage,
    JwtDecoderWrapper? jwtDecoder,
    SolidAuth? solidAuth,
    SolidProfileParser? profileParser,
  }) async {
    final service = SolidAuthServiceImpl._(
      loggerService: loggerService,
      client: client,
      secureStorage: secureStorage,
      jwtDecoder: jwtDecoder,
      solidAuth: solidAuth,
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
                _logger.warning('Token has expired, clearing session');
                await _clearSession();
              }
            }
          }
        } catch (e) {
          _logger.warning('Invalid access token, clearing session');
          await _clearSession();
        }
      }

      _logger.debug('Session restored: ${isAuthenticated ? 'Yes' : 'No'}');
    } catch (e, stackTrace) {
      _logger.error('Error restoring session', e, stackTrace);
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
      _logger.error('Error saving session', e, stackTrace);
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
      _logger.error('Error clearing session', e, stackTrace);
    }
  }

  // Auth state notification
  void _notifyAuthStateChange() {
    _authStateController.add(isAuthenticated);
  }

  @override
  Future<String> getIssuer(String input) async {
    return _solidAuth.getIssuer(input.trim());
  }

  @override
  Future<AuthResult> authenticate(
    String issuerUri,
    BuildContext context,
  ) async {
    try {
      final List<String> scopes = ['openid', 'profile', 'offline_access'];

      final authData = await _solidAuth.authenticate(
        Uri.parse(issuerUri),
        scopes,
        context,
      );

      _accessToken = authData['accessToken'];
      _decodedToken = _jwtDecoder.decode(_accessToken!);
      _currentWebId =
          _decodedToken!.containsKey('webid')
              ? _decodedToken!['webid']
              : _decodedToken!['sub'];
      _authData = Map<String, dynamic>.from(authData);

      // Get pod URL from WebID
      _podUrl = await resolvePodUrl(_currentWebId!);

      // Save session
      await _saveSession();

      _logger.info('Authentication successful: $_currentWebId');

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
      _logger.error('Authentication error', e, stackTrace);
      return AuthResult.error(e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      if (_authData != null && _authData!.containsKey('logoutUrl')) {
        await _solidAuth.logout(_authData!['logoutUrl']);
      }
    } catch (e, stackTrace) {
      _logger.error('Error during logout', e, stackTrace);
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
        _logger.warning('Failed to fetch profile: ${response.statusCode}');
        return null;
      }

      final contentType = response.headers['content-type'] ?? '';
      final data = response.body;

      return await _profileParser.parseStorageUrl(webId, data, contentType);
    } catch (e, stackTrace) {
      _logger.error('Error fetching pod URL', e, stackTrace);
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

      return _solidAuth.genDpopToken(url, rsaKeyPair, publicKeyJwk, method);
    } catch (e, stackTrace) {
      _logger.error('Error generating DPoP token', e, stackTrace);
      throw Exception('Failed to generate DPoP token: $e');
    }
  }

  /// Disposes resources when the service is no longer needed
  void dispose() {
    _authStateController.close();
  }
}
