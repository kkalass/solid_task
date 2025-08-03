import 'dart:async';

import 'package:solid_task/ext/solid/auth/models/user_identity.dart';
import 'package:solid_task/ext/solid/pod/storage/auth_based_storage_configuration_provider.dart';
import 'package:solid_task/ext/solid/pod/storage/pod_storage_configuration.dart';
import 'package:solid_task/ext/solid/pod/storage/static_storage_configuration_provider.dart';
import 'package:solid_task/ext/solid/pod/storage/strategy/default_triple_storage_strategy.dart';
import 'package:solid_task/ext/solid/pod/storage/strategy/triple_storage_strategy.dart';
import 'package:test/test.dart';

import '../../../../mocks/mock_solid_auth_state.dart';

class MockTripleStorageStrategy implements TripleStorageStrategy {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AuthBasedStorageConfigurationProvider', () {
    late MockSolidAuthState authState;
    late TripleStorageStrategy storageStrategy;
    late AuthBasedStorageConfigurationProvider provider;

    setUp(() {
      // Create mocks
      authState = MockSolidAuthState();
      storageStrategy = DefaultTripleStorageStrategy();

      // Configure mock behaviors

      // Create provider with mocked dependencies
      provider = AuthBasedStorageConfigurationProvider(
        authState: authState,
        storageStrategy: storageStrategy,
        appFolderRelPath: 'testapp',
      );
    });

    tearDown(() {
      authState.dispose();
    });

    test('initial configuration is null when not authenticated', () {
      expect(provider.currentConfiguration, isNull);
    });

    test('returns pod configuration when authenticated', () async {
      // Simulate user authentication
      final mockUser = UserIdentity(
        webId: 'https://alice.example.org/profile#me',
        podUrl: 'https://alice.example.org/',
      );
      authState.emitAuthStateChange(mockUser);

      // Manually trigger refresh
      await provider.refreshConfiguration();

      // Verify configuration is updated
      expect(provider.currentConfiguration, isNotNull);
      expect(
        provider.currentConfiguration?.storageRoot,
        equals('https://alice.example.org/'),
      );
      expect(
        provider.currentConfiguration?.appFolderRelPath,
        equals('testapp'),
      );
      expect(
        provider.currentConfiguration?.storageStrategy,
        equals(storageStrategy),
      );
    });

    test('updates configuration on auth state stream events', () async {
      // Setup for authenticated state
      final mockUser = UserIdentity(
        webId: 'https://alice.example.org/profile#me',
        podUrl: 'https://alice.example.org/',
      );

      // "login"
      authState.emitAuthStateChange(mockUser);

      // Allow stream event to be processed
      await Future.microtask(() {});

      // Verify configuration is updated
      expect(provider.currentConfiguration, isNotNull);
      expect(
        provider.currentConfiguration?.storageRoot,
        equals('https://alice.example.org/'),
      );
    });

    test('clears configuration when logged out', () async {
      // Set up initial authenticated state
      final mockUser = UserIdentity(
        webId: 'https://alice.example.org/profile#me',
        podUrl: 'https://alice.example.org/',
      );
      authState.emitAuthStateChange(mockUser);

      await provider.refreshConfiguration();

      // Verify initial state
      expect(provider.currentConfiguration, isNotNull);

      // Simulate logout
      authState.emitAuthStateChange(null);

      // Allow stream event to be processed
      await Future.microtask(() {});

      // Verify configuration cleared
      expect(provider.currentConfiguration, isNull);
    });
  });

  group('StaticStorageConfigurationProvider', () {
    test('always returns the same configuration', () async {
      final fixedConfig = PodStorageConfiguration(
        storageRoot: 'https://static.example.org/',
        appFolderRelPath: 'testapp',
        storageStrategy: DefaultTripleStorageStrategy(),
      );

      final provider = StaticStorageConfigurationProvider(fixedConfig);

      // Check initial state
      expect(provider.currentConfiguration, equals(fixedConfig));

      // Check refresh behavior
      final refreshed = await provider.refreshConfiguration();
      expect(refreshed, equals(fixedConfig));
    });

    test('can provide null configuration', () {
      final provider = StaticStorageConfigurationProvider(null);
      expect(provider.currentConfiguration, isNull);
    });
  });
}
