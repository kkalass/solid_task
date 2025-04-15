import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:solid_task/models/auth/auth_token.dart';
import 'package:solid_task/models/auth/user_identity.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/item_rdf_serializer.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:solid_task/services/rdf/rdf_parser.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/sync/solid_sync_service.dart';

import 'solid_sync_service_test.mocks.dart';

@GenerateMocks([
  http.Client,
  ItemRepository,
  SolidAuthState,
  SolidAuthOperations,
  ItemRdfSerializer,
  RdfParser,
  RdfParserFactory,
])
void main() {
  late MockClient mockClient;
  late MockItemRepository mockRepository;
  late MockSolidAuthState mockAuthState;
  late MockSolidAuthOperations mockAuthOperations;
  late MockItemRdfSerializer mockSerializer;
  late MockRdfParserFactory mockParserFactory;
  late MockRdfParser mockParser;
  late LoggerService loggerService;
  late SolidSyncService service;

  setUp(() {
    mockClient = MockClient();
    mockRepository = MockItemRepository();
    mockAuthState = MockSolidAuthState();
    mockAuthOperations = MockSolidAuthOperations();
    mockSerializer = MockItemRdfSerializer();
    mockParserFactory = MockRdfParserFactory();
    mockParser = MockRdfParser();
    loggerService = LoggerService();

    when(
      mockParserFactory.createParser(contentType: anyNamed('contentType')),
    ).thenReturn(mockParser);

    service = SolidSyncService(
      repository: mockRepository,
      authState: mockAuthState,
      authOperations: mockAuthOperations,
      loggerService: loggerService,
      client: mockClient,
      rdfSerializer: mockSerializer,
      rdfParserFactory: mockParserFactory,
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

    // Helper function to create sample items
    List<Item> createSampleItems(int count) {
      return List.generate(count, (index) {
        final item = Item(text: 'Item $index', lastModifiedBy: 'user1');
        item.id = 'item-$index';
        return item;
      });
    }

    // Helper function to simulate successful container creation
    void mockSuccessfulContainerCreation() {
      when(
        mockClient.head(
          Uri.parse('https://storage.example.org/tasks/'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('', 404));

      when(
        mockClient.put(
          Uri.parse('https://storage.example.org/tasks/'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('', 201));
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

    test(
      'syncToRemote should upload items as individual Turtle files',
      () async {
        // Arrange
        setupLoggedInUser();
        mockSuccessfulContainerCreation();

        final items = createSampleItems(3);
        when(mockRepository.getAllItems()).thenReturn(items);

        // Set up the serializer to return some Turtle content
        for (final item in items) {
          when(mockSerializer.itemToString(item)).thenReturn(
            '@prefix task: <http://example.org/> .\n<item> a task:Task .',
          );
        }

        // Set up successful HTTP responses for each item
        for (final item in items) {
          when(
            mockClient.put(
              Uri.parse('https://storage.example.org/tasks/${item.id}.ttl'),
              headers: anyNamed('headers'),
              body: anyNamed('body'),
            ),
          ).thenAnswer((_) async => http.Response('', 201));
        }

        // Act
        final result = await service.syncToRemote();

        // Assert
        expect(result.success, true);
        expect(result.itemsUploaded, 3);

        // Verify items were serialized
        for (final item in items) {
          verify(mockSerializer.itemToString(item)).called(1);
        }

        // Verify HTTP requests were made
        for (final item in items) {
          verify(
            mockClient.put(
              Uri.parse('https://storage.example.org/tasks/${item.id}.ttl'),
              headers: anyNamed('headers'),
              body: anyNamed('body'),
            ),
          ).called(1);
        }
      },
    );

    test('syncFromRemote should download and parse Turtle files', () async {
      // Arrange
      setupLoggedInUser();

      // Mock container exists check
      when(
        mockClient.head(
          Uri.parse('https://storage.example.org/tasks/'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('', 200));

      // Mock container listing
      final containerListing = '''
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      <> ldp:contains <https://storage.example.org/tasks/item-0.ttl> .
      <> ldp:contains <https://storage.example.org/tasks/item-1.ttl> .
      ''';

      when(
        mockClient.get(
          Uri.parse('https://storage.example.org/tasks/'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response(containerListing, 200));

      // Mock RDF parser for container listing
      final mockGraph = createMockGraph([
        'https://storage.example.org/tasks/item-0.ttl',
        'https://storage.example.org/tasks/item-1.ttl',
      ]);

      when(
        mockParser.parse(
          containerListing,
          documentUrl: 'https://storage.example.org/tasks/',
        ),
      ).thenReturn(mockGraph);

      // Mock item downloads
      final items = createSampleItems(2);

      for (int i = 0; i < items.length; i++) {
        final itemUrl = 'https://storage.example.org/tasks/item-$i.ttl';
        final itemContent =
            '@prefix task: <http://example.org/> .\n<item> a task:Task .';

        when(
          mockClient.get(Uri.parse(itemUrl), headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response(itemContent, 200));

        // Mock parsing the item content
        final itemId = 'item-$i';
        final itemUri = 'http://solidtask.org/tasks/$itemId';

        when(
          mockParser.parse(itemContent, documentUrl: itemUrl),
        ).thenReturn(mockGraph); // Use the same mock graph for simplicity

        when(mockSerializer.rdfToItem(mockGraph, itemUri)).thenReturn(items[i]);
      }

      // Act
      final result = await service.syncFromRemote();

      // Assert
      expect(result.success, true);
      expect(result.itemsDownloaded, 2);

      // Verify items were merged into the repository
      verify(mockRepository.mergeItems(items)).called(1);
    });

    test(
      'syncFromRemote should return empty result if container does not exist',
      () async {
        // Arrange
        setupLoggedInUser();

        // Mock container exists check - return 404 to indicate container doesn't exist
        when(
          mockClient.head(
            Uri.parse('https://storage.example.org/tasks/'),
            headers: anyNamed('headers'),
          ),
        ).thenAnswer((_) async => http.Response('', 404));

        // Act
        final result = await service.syncFromRemote();

        // Assert
        expect(result.success, true);
        expect(result.itemsDownloaded, 0);

        // Verify that no items were merged into the repository
        verifyNever(mockRepository.mergeItems(any));
      },
    );

    test('fullSync should handle both directions', () async {
      // Arrange
      setupLoggedInUser();
      mockSuccessfulContainerCreation();

      // Mock successful syncFromRemote
      when(
        mockClient.head(
          Uri.parse('https://storage.example.org/tasks/'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('', 200));

      when(
        mockClient.get(
          Uri.parse('https://storage.example.org/tasks/'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async =>
            http.Response('@prefix ldp: <http://www.w3.org/ns/ldp#> .', 200),
      );

      final mockGraph = createMockGraph([]);
      when(
        mockParser.parse(any, documentUrl: anyNamed('documentUrl')),
      ).thenReturn(mockGraph);

      // Mock empty item list
      when(mockRepository.getAllItems()).thenReturn([]);

      // Act
      final result = await service.fullSync();

      // Assert
      expect(result.success, true);
      expect(result.itemsDownloaded, 0);
      expect(result.itemsUploaded, 0);
    });

    test('fullSync should handle errors in syncFromRemote', () async {
      // Arrange
      setupLoggedInUser();

      // Mock error in syncFromRemote
      when(
        mockClient.head(
          Uri.parse('https://storage.example.org/tasks/'),
          headers: anyNamed('headers'),
        ),
      ).thenThrow(Exception('Network error'));

      // Ensure that both isConnected checks return true
      // Mocking getAllItems prevents a secondary error during syncToRemote
      when(mockRepository.getAllItems()).thenReturn([]);

      // Act
      final result = await service.fullSync();

      // Assert
      expect(result.success, false);
      expect(result.error, contains('Error syncing from pod'));
    });

    test(
      'startPeriodicSync should start timer and stopPeriodicSync should cancel it',
      () async {
        // Arrange
        setupLoggedInUser();
        mockSuccessfulContainerCreation();

        // Mock successful syncFromRemote for fullSync
        when(
          mockClient.head(
            Uri.parse('https://storage.example.org/tasks/'),
            headers: anyNamed('headers'),
          ),
        ).thenAnswer((_) async => http.Response('', 200));

        when(
          mockClient.get(
            Uri.parse('https://storage.example.org/tasks/'),
            headers: anyNamed('headers'),
          ),
        ).thenAnswer(
          (_) async =>
              http.Response('@prefix ldp: <http://www.w3.org/ns/ldp#> .', 200),
        );

        final mockGraph = createMockGraph([]);
        when(
          mockParser.parse(any, documentUrl: anyNamed('documentUrl')),
        ).thenReturn(mockGraph);

        when(mockRepository.getAllItems()).thenReturn([]);

        // Act & Assert
        service.startPeriodicSync(const Duration(seconds: 1));
        expect(service.syncTimer, true);

        service.stopPeriodicSync();
        expect(service.syncTimer, false);
      },
    );

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

    test(
      'syncToRemote should handle HTTP errors when uploading items',
      () async {
        // Arrange
        setupLoggedInUser();
        mockSuccessfulContainerCreation();

        final items = createSampleItems(2);
        when(mockRepository.getAllItems()).thenReturn(items);

        // Set up the serializer to return some Turtle content
        for (final item in items) {
          when(mockSerializer.itemToString(item)).thenReturn(
            '@prefix task: <http://example.org/> .\n<item> a task:Task .',
          );
        }

        // Set up mixed success/error HTTP responses
        when(
          mockClient.put(
            Uri.parse('https://storage.example.org/tasks/${items[0].id}.ttl'),
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async => http.Response('', 201)); // Success

        when(
          mockClient.put(
            Uri.parse('https://storage.example.org/tasks/${items[1].id}.ttl'),
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response('Permission denied', 403),
        ); // Error

        // Act
        final result = await service.syncToRemote();

        // Assert
        expect(result.success, true);
        expect(result.itemsUploaded, 1); // Only one item succeeded
      },
    );

    test(
      '_containerExists should propagate exceptions to syncFromRemote',
      () async {
        // Arrange
        setupLoggedInUser();

        // Mock a network error
        when(
          mockClient.head(
            Uri.parse('https://storage.example.org/tasks/'),
            headers: anyNamed('headers'),
          ),
        ).thenThrow(Exception('Network error'));

        // Act
        final result = await service.syncFromRemote();

        // Assert
        expect(result.success, false);
        expect(result.error, contains('Error syncing from pod'));
        expect(result.error, contains('Network error'));
      },
    );
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
