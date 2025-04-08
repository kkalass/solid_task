import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:solid_auth/solid_auth.dart' as solid_auth;
import 'package:solid_task/services/auth/auth_service.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/profile_parser.dart';
import 'package:flutter/services.dart';

/// Implementation of the AuthService for SOLID authentication
class SolidAuthService implements AuthService {
  final ContextLogger _logger;
  final http.Client _client;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

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

  SolidAuthService({required ContextLogger logger, required http.Client client})
    : _logger = logger,
      _client = client {
    // Try to restore session from secure storage
    _tryRestoreSession();
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
          _decodedToken = JwtDecoder.decode(_accessToken!);
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
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/solid_providers.json',
      );
      final data = json.decode(jsonString);
      return List<Map<String, dynamic>>.from(data['providers']);
    } catch (e, stackTrace) {
      _logger.error('Error loading providers', e, stackTrace);
      return [];
    }
  }

  @override
  Future<String> getIssuer(String input) async {
    return solid_auth.getIssuer(input.trim());
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

      final authData = await solid_auth.authenticate(
        Uri.parse(issuerUri),
        scopes,
        context,
      );

      _accessToken = authData['accessToken'];
      _decodedToken = JwtDecoder.decode(_accessToken!);
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
      return await solid_auth.fetchProfileData(webId);
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

      return await ProfileParser.parseStorageUrl(webId, data, contentType);
    } catch (e, stackTrace) {
      _logger.error('Error fetching pod URL', e, stackTrace);
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      if (_authData != null && _authData!.containsKey('logoutUrl')) {
        await solid_auth.logout(_authData!['logoutUrl']);
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

      return solid_auth.genDpopToken(url, rsaKeyPair, publicKeyJwk, method);
    } catch (e, stackTrace) {
      _logger.error('Error generating DPoP token', e, stackTrace);
      throw Exception('Failed to generate DPoP token: $e');
    }
  }
}
