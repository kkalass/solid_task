import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:solid_task/services/auth/auth_service.dart';
import 'package:solid_task/services/auth/jwt_decoder_wrapper.dart';
import 'package:solid_task/services/auth/solid_auth_wrapper.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/profile_parser.dart';

import 'package:solid_task/services/auth/provider_service.dart';
import 'package:solid_task/services/turtle_parser/turtle_parser.dart';

/// Implementation of the AuthService for SOLID authentication
class SolidAuthService implements AuthService {
  final ContextLogger _logger;
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  final JwtDecoderWrapper _jwtDecoder;
  final SolidAuth _solidAuth;
  final ProviderService _providerService;
  final ProfileParserService _profileParser;

  // Auth state
  String? _currentWebId;
  String? _podUrl;
  String? _accessToken;
  Map<String, dynamic>? _decodedToken;
  Map<String, dynamic>? _authData;

  // Storage keys
  static const String _webIdKey = 'solid_webid';
  static const String _podUrlKey = 'solid_pod_url';
  static const String _accessTokenKey = 'solid_access_token';
  static const String _authDataKey = 'solid_auth_data';

  // Add initialization state tracking
  late final Future<void> _initializationFuture;

  // Private constructor that captures dependencies
  SolidAuthService._({
    LoggerService? loggerService,
    required http.Client client,
    required ProviderService providerService,
    FlutterSecureStorage? secureStorage,
    JwtDecoderWrapper? jwtDecoder,
    SolidAuth? solidAuth,
    ProfileParserService? profileParser,
  }) : _logger = (loggerService ?? LoggerService()).createLogger(
         'SolidAuthService',
       ),
       _client = client,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _jwtDecoder = jwtDecoder ?? JwtDecoderWrapper(),
       // Pass the HTTP client to dependent components to ensure consistent mocking
       _solidAuth = solidAuth ?? SolidAuth(),
       _profileParser =
           profileParser ??
           DefaultProfileParser(
             loggerService: loggerService,
             turtleParser: DefaultTurtleParser(loggerService: loggerService),
           ),
       _providerService = providerService {
    // Create the initialization future but don't await it
    _initializationFuture = _initialize();
  }

  // Async initialization method
  Future<void> _initialize() async {
    try {
      await _tryRestoreSession();
    } catch (e, stackTrace) {
      _logger.error('Error during initialization', e, stackTrace);
    }
  }

  // Factory constructor for normal use
  static Future<SolidAuthService> create({
    required LoggerService loggerService,
    required http.Client client,
    required ProviderService providerService,
    FlutterSecureStorage? secureStorage,
    JwtDecoderWrapper? jwtDecoder,
    SolidAuth? solidAuth,
    ProfileParserService? profileParser,
  }) async {
    final service = SolidAuthService._(
      loggerService: loggerService,
      client: client,
      providerService: providerService,
      secureStorage: secureStorage,
      jwtDecoder: jwtDecoder,
      solidAuth: solidAuth,
      profileParser: profileParser,
    );

    // Wait for initialization to complete
    await service._initializationFuture;
    return service;
  }

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
        } catch (e) {
          // Token is invalid, clear session
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

  Future<void> _clearSession() async {
    try {
      await _secureStorage.deleteAll();
      _currentWebId = null;
      _podUrl = null;
      _accessToken = null;
      _decodedToken = null;
      _authData = null;
    } catch (e, stackTrace) {
      _logger.error('Error clearing session', e, stackTrace);
    }
  }

  @override
  bool get isAuthenticated => _currentWebId != null && _accessToken != null;

  @override
  String? get currentWebId => _currentWebId;

  @override
  String? get podUrl => _podUrl;

  @override
  String? get accessToken => _accessToken;

  @override
  Map<String, dynamic>? get decodedToken => _decodedToken;

  @override
  Map<String, dynamic>? get authData => _authData;

  @override
  Future<List<Map<String, dynamic>>> loadProviders() async {
    return _providerService.loadProviders();
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
      final List<String> scopes = <String>[
        'openid',
        'profile',
        'offline_access',
      ];

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
      _podUrl = await getPodUrl(_currentWebId!);

      // Save session
      await _saveSession();

      _logger.info('Authentication successful: $_currentWebId');

      return AuthResult(
        webId: _currentWebId,
        podUrl: _podUrl,
        accessToken: _accessToken,
        decodedToken: _decodedToken,
        authData: _authData,
      );
    } catch (e, stackTrace) {
      _logger.error('Authentication error', e, stackTrace);
      return AuthResult.error(e.toString());
    }
  }

  @override
  Future<String?> fetchProfileData(String webId) async {
    try {
      return await _solidAuth.fetchProfileData(webId);
    } catch (e, stackTrace) {
      _logger.error('Error fetching profile data', e, stackTrace);
      return null;
    }
  }

  @override
  Future<String?> getPodUrl(String webId) async {
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
  Future<void> logout() async {
    try {
      if (_authData != null && _authData!.containsKey('logoutUrl')) {
        await _solidAuth.logout(_authData!['logoutUrl']);
      }
    } catch (e, stackTrace) {
      _logger.error('Error during logout', e, stackTrace);
    } finally {
      await _clearSession();
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
}
