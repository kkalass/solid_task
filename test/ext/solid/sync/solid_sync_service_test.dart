import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/ext/solid/auth/models/user_identity.dart';
import 'package:solid_task/ext/solid/pod/storage/pod_storage_configuration.dart';
import 'package:solid_task/ext/solid/pod/storage/static_storage_configuration_provider.dart';
import 'package:solid_task/ext/solid/sync/rdf_repository.dart';
import 'package:solid_task/ext/solid/sync/solid_sync_service.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/solid_authentication_backend.dart';

import 'solid_sync_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<http.Client>(),
  MockSpec<RdfRepository>(),
  MockSpec<SolidAuthState>(),
  MockSpec<SolidAuthOperations>(),
])
void main() {
  late MockClient mockClient;
  late MockRdfRepository mockRepository;
  late MockSolidAuthState mockAuthState;
  late MockSolidAuthOperations mockAuthOperations;

  late SolidSyncService service;

  setUp(() {
    mockClient = MockClient();
    mockRepository = MockRdfRepository();
    mockAuthState = MockSolidAuthState();
    mockAuthOperations = MockSolidAuthOperations();

    service = SolidSyncService(
      repository: mockRepository,
      authState: mockAuthState,
      authOperations: mockAuthOperations,
      client: mockClient,
      rdfMapper: RdfMapper.withDefaultRegistry(),
      rdfCore: RdfCore.withStandardCodecs(),
      configProvider: StaticStorageConfigurationProvider(
        PodStorageConfiguration(storageRoot: "https://example.com/pod/"),
      ),
    );
  });

  group('SolidSyncService', () {
    // Helper function to set up a logged-in user
    void setupLoggedInUser() {
      final userInfo = UserIdentity(
        webId: 'https://user.example.org/profile/card#me',
        podUrl: 'https://storage.example.org/',
      );

      when(mockAuthState.isAuthenticated).thenReturn(true);
      when(mockAuthState.currentUser).thenReturn(userInfo);
      when(mockAuthOperations.generateDpopToken(any, any)).thenReturn(
        DPoP(dpopToken: 'mock-dpop-token', accessToken: 'mock-access-token'),
      );
    }

    test('isConnected should return authState.isAuthenticated', () {
      // Arrange
      when(mockAuthState.isAuthenticated).thenReturn(true);

      // Act & Assert
      expect(service.isConnected, true);

      // Arrange again
      when(mockAuthState.isAuthenticated).thenReturn(false);

      // Act & Assert again
      expect(service.isConnected, false);
    });

    test('userIdentifier should return user webId', () {
      // Arrange
      final userInfo = UserIdentity(
        webId: 'https://user.example.org/profile/card#me',
        podUrl: 'https://storage.example.org/',
      );
      when(mockAuthState.currentUser).thenReturn(userInfo);

      // Act & Assert
      expect(
        service.userIdentifier,
        'https://user.example.org/profile/card#me',
      );
    });

    test('dispose should stop periodic sync', () {
      // Arrange
      setupLoggedInUser();
      service.startPeriodicSync(const Duration(seconds: 1));
      expect(service.syncTimer, true);

      // Act
      service.dispose();

      // Assert
      expect(service.syncTimer, false);
    });
  });
}
