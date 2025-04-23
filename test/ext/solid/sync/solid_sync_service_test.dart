import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_graph.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf/core/graph/triple.dart';
import 'package:solid_task/ext/rdf/core/rdf_parser.dart';
import 'package:solid_task/ext/rdf/core/rdf_serializer.dart';
import 'package:solid_task/ext/rdf_orm/rdf_mapper_registry.dart';
import 'package:solid_task/ext/rdf_orm/rdf_mapper_service.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/ext/solid/auth/models/auth_token.dart';
import 'package:solid_task/ext/solid/auth/models/user_identity.dart';
import 'package:solid_task/ext/solid/pod/storage/pod_storage_configuration.dart';
import 'package:solid_task/ext/solid/pod/storage/static_storage_configuration_provider.dart';
import 'package:solid_task/ext/solid/sync/solid_sync_service.dart';
import 'package:solid_task/ext/solid/sync/rdf_repository.dart';

import 'solid_sync_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<http.Client>(),
  MockSpec<RdfRepository>(),
  MockSpec<SolidAuthState>(),
  MockSpec<SolidAuthOperations>(),
  MockSpec<RdfParser>(),
  MockSpec<RdfParserFactoryBase>(),
  MockSpec<RdfSerializerFactoryBase>(),
])
void main() {
  // Provide a dummy value for RdfGraph to solve the MissingDummyValueError
  provideDummy<RdfGraph>(RdfGraph());

  late MockClient mockClient;
  late MockRdfRepository mockRepository;
  late MockSolidAuthState mockAuthState;
  late MockSolidAuthOperations mockAuthOperations;
  late MockRdfParserFactoryBase mockParserFactory;
  late MockRdfSerializerFactoryBase mockSerializerFactory;
  late MockRdfParser mockParser;
  late SolidSyncService service;

  setUp(() {
    mockClient = MockClient();
    mockRepository = MockRdfRepository();
    mockAuthState = MockSolidAuthState();
    mockAuthOperations = MockSolidAuthOperations();
    mockParserFactory = MockRdfParserFactoryBase();
    mockSerializerFactory = MockRdfSerializerFactoryBase();
    mockParser = MockRdfParser();

    when(
      mockParserFactory.createParser(contentType: anyNamed('contentType')),
    ).thenReturn(mockParser);

    service = SolidSyncService(
      repository: mockRepository,
      authState: mockAuthState,
      authOperations: mockAuthOperations,
      client: mockClient,
      rdfParserFactory: mockParserFactory,
      rdfSerializerFactory: mockSerializerFactory,
      rdfMapperService: RdfMapperService(registry: RdfMapperRegistry()),
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
      final authToken = AuthToken(
        accessToken: 'mock-access-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      when(mockAuthState.isAuthenticated).thenReturn(true);
      when(mockAuthState.currentUser).thenReturn(userInfo);
      when(mockAuthState.authToken).thenReturn(authToken);
      when(
        mockAuthOperations.generateDpopToken(any, any),
      ).thenReturn('mock-dpop-token');
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

// Helper to create a mock RDF graph with container listing
RdfGraph createMockGraph(List<String> fileUrls) {
  return RdfGraph(
    triples:
        fileUrls
            .map(
              (fileUrl) => Triple(
                IriTerm('https://example.com/container'),
                IriTerm('http://www.w3.org/ns/ldp#contains'),
                IriTerm(fileUrl),
              ),
            )
            .toList(),
  );
}
