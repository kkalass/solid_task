import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:solid_auth/solid_auth.dart';
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
  String? _podUrl;

  // Storage keys
  static const String _podUrlKey = 'solid_pod_url';

  // Initialization tracking
  late final Future<void> _initializationFuture;

  @override
  bool get isAuthenticated => _authBackend.isAuthenticatedNotifier.value;

  @override
  UserIdentity? get currentUser {
    if (!isAuthenticated) return null;
    return UserIdentity(webId: _authBackend.currentWebId!, podUrl: _podUrl);
  }

  @override
  ValueListenable<bool> get authStateChanges =>
      _authBackend.isAuthenticatedNotifier;

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
      // Initialize the authentication backend and check for existing session
      final hasExistingSession = await _authBackend.initialize();

      if (hasExistingSession) {
        // Restore session data from the backend
        final currentWebId = _authBackend.currentWebId;

        if (currentWebId != null) {
          // Get pod URL from WebID (this was previously stored in secure storage)
          _podUrl = await _secureStorage.read(key: _podUrlKey);
          if (_podUrl == null) {
            // If pod URL not cached, resolve it
            _podUrl = await resolvePodUrl(currentWebId);
            await _secureStorage.write(key: _podUrlKey, value: _podUrl);
          }

          _log.info('Session restored from backend: $currentWebId');
        }
      }
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

  // Session cleanup
  Future<void> _clearStorage() async {
    try {
      await _secureStorage.delete(key: _podUrlKey);
      _podUrl = null;
    } catch (e, stackTrace) {
      _log.severe('Error clearing session', e, stackTrace);
    }
  }

  @override
  Future<AuthResult> authenticate(
    String webIdOrIssuerUri,
    BuildContext context,
  ) async {
    try {
      final List<String> scopes = ['openid', 'offline_access', 'webid'];

      final authData = await _authBackend.authenticate(
        webIdOrIssuerUri,
        scopes,
        context,
      );

      final webId = authData.webId;

      // Get pod URL from WebID
      _podUrl = await resolvePodUrl(webId);
      await _secureStorage.write(key: _podUrlKey, value: _podUrl);

      _log.info('Authentication successful: $webId');

      // Create result objects using our model classes
      final userIdentity = UserIdentity(webId: webId, podUrl: _podUrl);

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
      await _clearStorage();
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
  DPoP generateDpopToken(String url, String method) =>
      _authBackend.genDpopToken(url, method);

  /// Disposes resources when the service is no longer needed
  Future<void> dispose() async {
    await _authBackend.dispose();
  }
}
