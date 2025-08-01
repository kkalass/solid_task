import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:solid_task/bootstrap/service_locator.dart';
import 'package:solid_task/bootstrap/service_locator_builder.dart';
import 'package:solid_task/ext/solid/auth/interfaces/auth_state_change_provider.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_provider_service.dart';
import 'package:solid_task/ext/solid/sync/sync_manager.dart';
import 'package:solid_task/ext/solid/sync/sync_service.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/jwt_decoder_wrapper.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/solid_authentication_backend.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';
import 'package:solid_task/services/client_id_service.dart';

import '../mocks/mock_temp_dir_path_provider.dart';
@GenerateNiceMocks([
  MockSpec<LoggerService>(),
  MockSpec<http.Client>(),
  MockSpec<LocalStorageService>(),
  MockSpec<SolidProviderService>(),
  MockSpec<SolidAuthOperations>(),
  MockSpec<AuthStateChangeProvider>(),
  MockSpec<SolidAuthState>(),
  MockSpec<ItemRepository>(),
  MockSpec<SyncService>(),
  MockSpec<SyncManager>(),
  MockSpec<SolidAuthenticationBackend>(),
  MockSpec<FlutterSecureStorage>(),
  MockSpec<ContextLogger>(),
  MockSpec<JwtDecoderWrapper>(),
  MockSpec<ClientIdService>(),
])
import 'service_locator_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServiceLocator Builder', () {
    late MockJwtDecoderWrapper mockJwtDecoderWrapper;
    late MockLoggerService mockLogger;
    late MockClient mockClient;
    late MockLocalStorageService mockStorage;
    late MockSolidProviderService mockSolidProviderService;
    late MockSolidAuthState mockSolidAuthState;
    late MockSolidAuthOperations mockSolidAuthOperations;
    late MockAuthStateChangeProvider mockAuthStateChangeProvider;
    late MockItemRepository mockItemRepository;
    late MockSyncService mockSyncService;
    late MockSyncManager mockSyncManager;
    late MockFlutterSecureStorage mockSecureStorage;
    late MockSolidAuthenticationBackend mockSolidAuth;
    late MockContextLogger mockContextLogger;
    late MockTempDirPathProvider mockPathProvider;

    setUpAll(() {
      mockPathProvider = MockTempDirPathProvider(
        prefix: "test_service_locator",
      );
      PathProviderPlatform.instance = mockPathProvider;
    });

    tearDownAll(() async {
      await mockPathProvider.cleanup();
    });

    setUp(() {
      // Create all mocks
      mockJwtDecoderWrapper = MockJwtDecoderWrapper();
      mockLogger = MockLoggerService();
      mockClient = MockClient();
      mockStorage = MockLocalStorageService();
      mockSolidProviderService = MockSolidProviderService();
      mockSolidAuthState = MockSolidAuthState();
      mockSolidAuthOperations = MockSolidAuthOperations();
      mockAuthStateChangeProvider = MockAuthStateChangeProvider();
      mockItemRepository = MockItemRepository();
      mockSyncService = MockSyncService();
      mockSyncManager = MockSyncManager();
      mockSecureStorage = MockFlutterSecureStorage();
      mockSolidAuth = MockSolidAuthenticationBackend();
      mockContextLogger = MockContextLogger();

      // Configure default mock behavior
      when(mockLogger.createLogger(any)).thenReturn(mockContextLogger);
    });

    tearDown(() async {
      await sl.reset();
    });

    test('should register and resolve all services properly', () async {
      // Initialize the service locator with minimal configuration
      await initServiceLocator(
        configure: (builder) {
          builder
              .withSecureStorageFactory((_) => mockSecureStorage)
              .withLoggerFactory((_) => mockLogger);
        },
      );

      // Verify services are registered
      expect(sl.isRegistered<SolidAuthOperations>(), isTrue);
      expect(sl.isRegistered<SolidAuthState>(), isTrue);
      expect(sl.isRegistered<AuthStateChangeProvider>(), isTrue);
      expect(sl.isRegistered<ItemRepository>(), isTrue);
      expect(sl.isRegistered<SyncService>(), isTrue);
      expect(sl.isRegistered<ClientIdService>(), isTrue);

      // Verify we can resolve services
      expect(sl<AuthStateChangeProvider>(), isNotNull);
      expect(sl<SolidAuthOperations>(), isNotNull);
      expect(sl<SolidAuthState>(), isNotNull);
      expect(sl<ItemRepository>(), isNotNull);
      expect(sl<SyncService>(), isNotNull);
      expect(sl<ClientIdService>(), isNotNull);
    });

    test(
      'should register and resolve services with custom implementations via builder',
      () async {
        // Initialize with full custom configuration
        await initServiceLocator(
          configure: (builder) {
            builder
                .withLoggerFactory((_) => mockLogger)
                .withHttpClientFactory((_) => mockClient)
                .withStorageServiceFactory((_) => mockStorage)
                .withProviderServiceFactory((_) => mockSolidProviderService)
                .withSecureStorageFactory((_) => mockSecureStorage)
                .withSolidAuthFactory((_) => mockSolidAuth)
                .withJwtDecoderFactory((_) => mockJwtDecoderWrapper)
                .withSolidAuthStateFactory((_) {
                  return mockSolidAuthState;
                })
                .withSolidAuthOperationsFactory((_) => mockSolidAuthOperations)
                .withAuthStateChangeProviderFactory(
                  (_) => mockAuthStateChangeProvider,
                )
                .withItemRepositoryFactory((_) => mockItemRepository)
                .withSyncServiceFactory((_) => mockSyncService)
                .withSyncManagerFactory((_) => mockSyncManager);
          },
        );

        // Verify our mocks were registered correctly
        expect(sl<LoggerService>(), same(mockLogger));
        expect(sl<http.Client>(), same(mockClient));
        expect(sl<LocalStorageService>(), same(mockStorage));
        expect(sl<SolidProviderService>(), same(mockSolidProviderService));
        expect(sl<FlutterSecureStorage>(), same(mockSecureStorage));
        expect(sl<SolidAuthenticationBackend>(), same(mockSolidAuth));

        expect(sl<SolidAuthState>(), same(mockSolidAuthState));
        expect(sl<SolidAuthOperations>(), same(mockSolidAuthOperations));
        expect(
          sl<AuthStateChangeProvider>(),
          same(mockAuthStateChangeProvider),
        );

        // Check repositories
        expect(
          sl<ItemRepository>(instanceName: 'baseRepository'),
          same(mockItemRepository),
        );
        expect(sl<SyncService>(), same(mockSyncService));
      },
    );

    test('allows partial configuration with builder', () async {
      // Only replace specific dependencies
      await initServiceLocator(
        configure: (builder) {
          builder
              .withSecureStorageFactory((_) => mockSecureStorage)
              .withSolidAuthFactory((_) => mockSolidAuth);
        },
      );

      // Verify only specified services are replaced
      expect(sl<FlutterSecureStorage>(), same(mockSecureStorage));
      expect(sl<SolidAuthenticationBackend>(), same(mockSolidAuth));

      // Other services use default implementations
      expect(sl<LoggerService>(), isNot(same(mockLogger)));
      expect(sl<http.Client>(), isNot(same(mockClient)));
    });

    test('async service registration completes successfully', () async {
      // Setup mock secure storage with pre-existing authentication data
      mockSecureStorage = MockFlutterSecureStorage();

      when(
        mockSecureStorage.read(key: 'solid_webid'),
      ).thenAnswer((_) async => 'https://example.org/profile/card#me');
      when(
        mockSecureStorage.read(key: 'solid_pod_url'),
      ).thenAnswer((_) async => 'https://example.org');
      when(
        mockSecureStorage.read(key: 'device_client_id'),
      ).thenAnswer((_) async => 'test-client-id-123');

      mockJwtDecoderWrapper = MockJwtDecoderWrapper();
      when(mockJwtDecoderWrapper.decode(any)).thenReturn({
        'sub': 'https://example.org/profile/card#me',
        'exp': DateTime.now().add(Duration(days: 1)).millisecondsSinceEpoch,
      });

      // Configure SolidAuth mock to simulate successful token restoration
      mockSolidAuth = MockSolidAuthenticationBackend();

      // Initialize with our mocked services
      await initServiceLocator(
        configure: (builder) {
          builder
              .withHttpClientFactory((_) => mockClient)
              .withProviderServiceFactory((_) => mockSolidProviderService)
              .withSecureStorageFactory((_) => mockSecureStorage)
              .withSolidAuthFactory((_) => mockSolidAuth)
              .withJwtDecoderFactory((_) => mockJwtDecoderWrapper)
              .withLoggerFactory((_) => mockLogger);
        },
      );

      // Verify the async service is ready and properly restored the session
      await sl.isReady<SolidAuthState>();

      // Verify session data was correctly restored
      expect(sl<SolidAuthState>().isAuthenticated, isTrue);
      expect(
        sl<SolidAuthState>().currentUser?.webId,
        equals('https://example.org/profile/card#me'),
      );
      expect(
        sl<SolidAuthState>().currentUser?.podUrl,
        equals('https://example.org'),
      );

      // Verify secure storage was queried for authentication data
      verify(mockSecureStorage.read(key: 'solid_webid')).called(1);
      verify(mockSecureStorage.read(key: 'solid_pod_url')).called(1);
      // Note: solid_auth_data and solid_access_token are currently not used
      // as the token restoration logic is commented out in SolidAuthServiceImpl
    });

    test('service locator can properly reset', () async {
      // Setup with a simple configuration
      await initServiceLocator(
        configure: (builder) {
          builder
              .withSecureStorageFactory((_) => mockSecureStorage)
              .withLoggerFactory((_) => mockLogger);
        },
      );

      expect(sl.isRegistered<FlutterSecureStorage>(), isTrue);

      // Act - reset the service locator
      await sl.reset();

      // Verify - all registrations should be cleared
      expect(sl.isRegistered<FlutterSecureStorage>(), isFalse);
      expect(sl.isRegistered<AuthStateChangeProvider>(), isFalse);
      expect(sl.isRegistered<SolidAuthOperations>(), isFalse);
      expect(sl.isRegistered<SolidAuthState>(), isFalse);
      expect(sl.isRegistered<ItemRepository>(), isFalse);
    });

    test('ServiceLocatorBuilder provides a fluent API', () async {
      // This test validates the fluent API design pattern
      ServiceLocatorBuilder? firstBuilder;
      ServiceLocatorBuilder? result;
      await initServiceLocator(
        configure: (builder) {
          firstBuilder = builder;
          result = builder
              .withLoggerFactory((_) => mockLogger)
              .withHttpClientFactory((_) => mockClient)
              .withSecureStorageFactory((_) => mockSecureStorage)
              .withJwtDecoderFactory((_) => mockJwtDecoderWrapper)
              .withStorageServiceFactory((_) => mockStorage)
              .withProviderServiceFactory((_) => mockSolidProviderService)
              .withSolidAuthFactory((_) => mockSolidAuth)
              .withSolidAuthStateFactory((_) => mockSolidAuthState)
              .withSolidAuthOperationsFactory((_) => mockSolidAuthOperations)
              .withAuthStateChangeProviderFactory(
                (_) => mockAuthStateChangeProvider,
              )
              .withItemRepositoryFactory((_) => mockItemRepository)
              .withSyncServiceFactory((_) => mockSyncService)
              .withSyncManagerFactory((_) => mockSyncManager)
              .withSyncableRepositoryFactory((_) => mockItemRepository);
        },
      );

      // Should return the builder for chaining
      expect(result, same(firstBuilder));
    });
  });
}
