import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:solid_task/services/auth/auth_service.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/sync/solid_sync_service.dart';
import 'dart:convert';

@GenerateMocks([http.Client, ItemRepository, AuthService, ContextLogger])
import 'solid_sync_service_test.mocks.dart';

void main() {
  group('SolidSyncService', () {
    late MockClient mockHttpClient;
    late MockItemRepository mockRepository;
    late MockAuthService mockAuthService;
    late MockContextLogger mockLogger;
    late SolidSyncService syncService;

    setUp(() {
      mockHttpClient = MockClient();
      mockRepository = MockItemRepository();
      mockAuthService = MockAuthService();
      mockLogger = MockContextLogger();

      // Setup standard authentication state
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(
        mockAuthService.currentWebId,
      ).thenReturn('https://user.example/profile/card#me');
      when(mockAuthService.podUrl).thenReturn('https://pod.example/storage/');
      when(mockAuthService.accessToken).thenReturn('mock-access-token');
      when(
        mockAuthService.generateDpopToken(any, any),
      ).thenReturn('mock-dpop-token');

      syncService = SolidSyncService(
        repository: mockRepository,
        authService: mockAuthService,
        logger: mockLogger,
        client: mockHttpClient,
      );
    });

    test('isConnected returns auth service authentication status', () {
      // Default setup has isAuthenticated = true
      expect(syncService.isConnected, isTrue);

      // Change auth status
      when(mockAuthService.isAuthenticated).thenReturn(false);
      expect(syncService.isConnected, isFalse);
    });

    test('userIdentifier returns the current WebID', () {
      expect(
        syncService.userIdentifier,
        'https://user.example/profile/card#me',
      );
    });

    test('syncToRemote sends local items to the pod', () async {
      // Setup repository response
      final mockItems = [
        {
          'id': '1',
          'text': 'Item 1',
          'createdAt': DateTime.now().toIso8601String(),
          'vectorClock': {'user1': 1},
          'isDeleted': false,
          'lastModifiedBy': 'user1',
        },
        {
          'id': '2',
          'text': 'Item 2',
          'createdAt': DateTime.now().toIso8601String(),
          'vectorClock': {'user1': 1},
          'isDeleted': false,
          'lastModifiedBy': 'user1',
        },
      ];
      when(mockRepository.exportItems()).thenReturn(mockItems);

      // Setup HTTP response
      when(
        mockHttpClient.put(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('Success', 200));

      // Execute
      final result = await syncService.syncToRemote();

      // Verify
      expect(result.success, isTrue);
      expect(result.itemsUploaded, 2);

      // Verify correct HTTP request was made
      verify(
        mockAuthService.generateDpopToken(
          'https://pod.example/storage/todos.json',
          'PUT',
        ),
      ).called(1);

      verify(
        mockHttpClient.put(
          Uri.parse('https://pod.example/storage/todos.json'),
          headers: {
            'Accept': '*/*',
            'Authorization': 'DPoP mock-access-token',
            'Connection': 'keep-alive',
            'Content-Type': 'application/json',
            'DPoP': 'mock-dpop-token',
          },
          body: jsonEncode(mockItems),
        ),
      ).called(1);

      verify(mockLogger.info(any)).called(1);
    });

    test('syncToRemote returns error when not connected', () async {
      // Setup - not authenticated
      when(mockAuthService.isAuthenticated).thenReturn(false);

      // Execute
      final result = await syncService.syncToRemote();

      // Verify
      expect(result.success, isFalse);
      expect(result.error, contains('Not connected'));
      verifyNever(
        mockHttpClient.put(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      );
    });

    test('syncToRemote returns error when pod URL is null', () async {
      // Setup - no pod URL
      when(mockAuthService.podUrl).thenReturn(null);

      // Execute
      final result = await syncService.syncToRemote();

      // Verify
      expect(result.success, isFalse);
      expect(result.error, contains('Pod URL not available'));
      verifyNever(
        mockHttpClient.put(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      );
    });

    test('syncToRemote returns error when HTTP request fails', () async {
      // Setup repository response
      when(mockRepository.exportItems()).thenReturn([]);

      // Setup HTTP error response
      when(
        mockHttpClient.put(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('Error', 403));

      // Execute
      final result = await syncService.syncToRemote();

      // Verify
      expect(result.success, isFalse);
      expect(result.error, contains('403'));
      verify(mockLogger.error(any, any, any)).called(1);
    });

    test('syncFromRemote gets items from the pod and imports them', () async {
      // Setup mock response data
      final mockJsonResponse = [
        {
          'id': '1',
          'text': 'Remote Item 1',
          'createdAt': DateTime.now().toIso8601String(),
          'vectorClock': {'remote': 1},
          'isDeleted': false,
          'lastModifiedBy': 'remote',
        },
      ];

      // Setup HTTP response
      when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response(jsonEncode(mockJsonResponse), 200),
      );

      // Setup repository
      when(mockRepository.importItems(any)).thenAnswer((_) async {});

      // Execute
      final result = await syncService.syncFromRemote();

      // Verify
      expect(result.success, isTrue);
      expect(result.itemsDownloaded, 1);

      // Verify HTTP request
      verify(
        mockAuthService.generateDpopToken(
          'https://pod.example/storage/todos.json',
          'GET',
        ),
      ).called(1);
      verify(
        mockHttpClient.get(
          Uri.parse('https://pod.example/storage/todos.json'),
          headers: {
            'Accept': '*/*',
            'Authorization': 'DPoP mock-access-token',
            'Connection': 'keep-alive',
            'DPoP': 'mock-dpop-token',
          },
        ),
      ).called(1);

      // Verify items were imported
      verify(mockRepository.importItems(any)).called(1);
    });

    test('syncFromRemote handles 404 gracefully when no file exists', () async {
      // Setup HTTP 404 response
      when(
        mockHttpClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response('Not Found', 404));

      // Execute
      final result = await syncService.syncFromRemote();

      // Verify - this should be successful with 0 items
      expect(result.success, isTrue);
      expect(result.itemsDownloaded, 0);
      verifyNever(mockRepository.importItems(any));
    });

    test('fullSync performs both download and upload operations', () async {
      // Setup mock response data
      final mockJsonResponse = [
        {'id': '1', 'text': 'Remote Item'},
      ];

      // Setup HTTP responses
      when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response(jsonEncode(mockJsonResponse), 200),
      );

      when(
        mockHttpClient.put(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('Success', 200));

      // Setup repository
      when(mockRepository.importItems(any)).thenAnswer((_) async {});
      when(mockRepository.exportItems()).thenReturn([
        {'id': '2', 'text': 'Local Item'},
      ]);

      // Execute
      final result = await syncService.fullSync();

      // Verify
      expect(result.success, isTrue);
      expect(result.itemsDownloaded, 1);
      expect(result.itemsUploaded, 1);

      // Verify both operations happened
      verify(mockHttpClient.get(any, headers: anyNamed('headers'))).called(1);
      verify(
        mockHttpClient.put(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).called(1);
    });

    test(
      'startPeriodicSync starts a timer and stopPeriodicSync stops it',
      () async {
        // This is mostly a smoke test as we can't easily test the timer directly

        // Execute
        syncService.startPeriodicSync(Duration(minutes: 5));

        // Verify logger was called
        verify(mockLogger.info(any)).called(1);

        // Stop sync and verify
        syncService.stopPeriodicSync();
        verify(mockLogger.info(any)).called(1);
      },
    );

    test('dispose stops periodic sync and logs', () {
      // Execute
      syncService.dispose();

      // Verify
      verify(mockLogger.debug(any)).called(1);
    });
  });
}
