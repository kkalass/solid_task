import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:solid_task/core/providers.dart';
import 'package:solid_task/services/auth/interfaces/auth_state_change_provider.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/services/auth/interfaces/solid_provider_service.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/sync/sync_manager.dart';
import 'package:solid_task/services/sync/sync_service.dart';

import '../helpers/riverpod_test_helper.dart';
import '../mocks/mock_temp_dir_path_provider.dart';
import '../widget_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Riverpod Provider Tests', () {
    late MockLoggerService mockLogger;
    late MockSolidProviderService mockProviderService;
    late MockSolidAuthState mockAuthState;
    late MockSolidAuthOperations mockAuthOperations;
    late MockAuthStateChangeProvider mockAuthStateChangeProvider;
    late MockItemRepository mockItemRepository;
    late MockSyncService mockSyncService;
    late MockSyncManager mockSyncManager;
    late MockContextLogger mockContextLogger;
    late MockTempDirPathProvider mockPathProvider;
    late TestProviderContainer testContainer;

    setUpAll(() {
      mockPathProvider = MockTempDirPathProvider(
        prefix: "test_providers",
      );
      PathProviderPlatform.instance = mockPathProvider;
    });

    tearDownAll(() async {
      await mockPathProvider.cleanup();
    });

    setUp(() {
      // Create all mocks
      mockLogger = MockLoggerService();
      mockProviderService = MockSolidProviderService();
      mockAuthState = MockSolidAuthState();
      mockAuthOperations = MockSolidAuthOperations();
      mockAuthStateChangeProvider = MockAuthStateChangeProvider();
      mockItemRepository = MockItemRepository();
      mockSyncService = MockSyncService();
      mockSyncManager = MockSyncManager();
      mockContextLogger = MockContextLogger();

      // Configure default mock behavior
      when(mockLogger.createLogger(any)).thenReturn(mockContextLogger);
      when(mockSyncManager.syncStatusStream).thenAnswer(
        (_) => Stream.value(SyncStatus.idle()),
      );
      when(mockSyncManager.isSyncing).thenReturn(false);
      when(mockSyncManager.hasError).thenReturn(false);
    });

    tearDown(() {
      // Dispose container if it was created
      testContainer.dispose();
    });

    test('Provider container should properly initialize and provide services', () {
      // Create a provider container with no overrides
      testContainer = TestProviderContainer();
      
      // Verify core services are provided
      expect(testContainer.container.read(loggerServiceProvider), isA<LoggerService>());
      expect(testContainer.container.read(httpClientProvider), isA<http.Client>());
      expect(testContainer.container.read(solidProviderServiceProvider), isA<SolidProviderService>());
    });
    
    test('Providing mocked services works properly', () {
      // Create a provider container with mocked services
      testContainer = TestProviderContainer(
        loggerService: mockLogger,
        providerService: mockProviderService,
        authState: mockAuthState,
        authOperations: mockAuthOperations,
        authStateChangeProvider: mockAuthStateChangeProvider,
        itemRepository: mockItemRepository,
        syncService: mockSyncService,
        syncManager: mockSyncManager,
      );
      
      // Verify mocks are provided
      expect(testContainer.container.read(loggerServiceProvider), same(mockLogger));
      expect(testContainer.container.read(solidProviderServiceProvider), same(mockProviderService));
      expect(testContainer.container.read(solidAuthStateProvider), same(mockAuthState));
      expect(testContainer.container.read(solidAuthOperationsProvider), same(mockAuthOperations));
      expect(testContainer.container.read(baseItemRepositoryProvider), same(mockItemRepository));
      expect(testContainer.container.read(syncServiceProvider), same(mockSyncService));
    });
    
    test('Repository provider uses the syncable repository when sync manager is available', () async {
      // Setup auth state to be authenticated
      when(mockAuthState.isAuthenticated).thenReturn(true);
      when(mockAuthState.currentUser?.webId).thenReturn('https://example.org/profile/card#me');
      
      // Create a provider container with all necessary mocks
      testContainer = TestProviderContainer(
        authState: mockAuthState,
        itemRepository: mockItemRepository,
        syncManager: mockSyncManager,
      );
      
      // Read the syncable repository provider
      final repository = testContainer.container.read(syncableItemRepositoryProvider);
      
      // Verify it's the syncable decorator (not the original mock)
      expect(repository, isNot(same(mockItemRepository)));
      
      // Call a method to verify delegation
      await repository.createItem('Test task', 'user123');
      
      // Verify the mock was called
      verify(mockItemRepository.createItem('Test task', 'user123')).called(1);
    });
  });
}