import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:solid_task/core/service_locator.dart';
import 'package:solid_task/services/auth/auth_service.dart';
import 'package:solid_task/services/auth/jwt_decoder_wrapper.dart';
import 'package:solid_task/services/auth/provider_service.dart';
import 'package:solid_task/services/auth/solid_auth_wrapper.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';
import 'package:solid_task/services/sync/sync_service.dart';

// Generate mocks for all services
import '../mocks/mock_temp_dir_path_provider.dart';
@GenerateNiceMocks([
  MockSpec<LoggerService>(),
  MockSpec<http.Client>(),
  MockSpec<LocalStorageService>(),
  MockSpec<ProviderService>(),
  MockSpec<AuthService>(),
  MockSpec<ItemRepository>(),
  MockSpec<SyncService>(),
  MockSpec<SolidAuth>(),
  MockSpec<FlutterSecureStorage>(),
  MockSpec<ContextLogger>(),
  MockSpec<JwtDecoderWrapper>(),
])
import 'service_locator_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServiceLocator', () {
    late MockJwtDecoderWrapper mockJwtDecoderWrapper;
    late MockLoggerService mockLogger;
    late MockClient mockClient;
    late MockLocalStorageService mockStorage;
    late MockProviderService mockProviderService;
    late MockAuthService mockAuthService;
    late MockItemRepository mockItemRepository;
    late MockSyncService mockSyncService;
    late MockFlutterSecureStorage mockSecureStorage;
    late MockSolidAuth mockSolidAuth;
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
      mockProviderService = MockProviderService();
      mockAuthService = MockAuthService();
      mockItemRepository = MockItemRepository();
      mockSyncService = MockSyncService();
      mockSecureStorage = MockFlutterSecureStorage();
      mockSolidAuth = MockSolidAuth();
      mockContextLogger = MockContextLogger();

      // Configure default mock behavior
      when(mockStorage.init()).thenAnswer((_) async {});
      when(mockLogger.createLogger(any)).thenReturn(mockContextLogger);
    });

    tearDown(() async {
      await sl.reset();
    });

    test('should register and resolve all services properly', () async {
      // Initialize the service locator
      await initServiceLocator(
        config: ServiceLocatorConfig(
          secureStorage: mockSecureStorage,
          loggerService: mockLogger,
        ),
      );

      // Verify services are registered
      expect(sl.isRegistered<AuthService>(), isTrue);
      expect(sl.isRegistered<ItemRepository>(), isTrue);
      expect(sl.isRegistered<SyncService>(), isTrue);

      // Verify we can resolve services
      expect(sl<AuthService>(), isNotNull);
      expect(sl<ItemRepository>(), isNotNull);
      expect(sl<SyncService>(), isNotNull);
    });

    test(
      'should register and resolve services with custom implementations via config',
      () async {
        // Create the config with our mocks
        final config = ServiceLocatorConfig(
          loggerService: mockLogger,
          httpClient: mockClient,
          storageService: mockStorage,
          providerService: mockProviderService,
          secureStorage: mockSecureStorage,
          solidAuth: mockSolidAuth,
          jwtDecoder: mockJwtDecoderWrapper,
          authServiceFactory: (_, __, ___) async => mockAuthService,
          itemRepositoryFactory: (_, __) => mockItemRepository,
          syncServiceFactory: (_, __, ___, ____) => mockSyncService,
        );

        // Initialize with our config
        await initServiceLocator(config: config);

        // Verify our mocks were registered correctly
        expect(sl<LoggerService>(), same(mockLogger));
        expect(sl<http.Client>(), same(mockClient));
        expect(sl<LocalStorageService>(), same(mockStorage));
        expect(sl<ProviderService>(), same(mockProviderService));
        expect(sl<FlutterSecureStorage>(), same(mockSecureStorage));
        expect(sl<SolidAuth>(), same(mockSolidAuth));
        expect(sl<AuthService>(), same(mockAuthService));
        expect(sl<ItemRepository>(), same(mockItemRepository));
        expect(sl<SyncService>(), same(mockSyncService));

        // Verify init was called on the storage service
        verify(mockStorage.init()).called(1);
      },
    );

    test('allows partial configuration replacement', () async {
      // Only replace specific dependencies
      final config = ServiceLocatorConfig(
        secureStorage: mockSecureStorage,
        solidAuth: mockSolidAuth,
      );

      // Initialize with partial config
      await initServiceLocator(config: config);

      // Verify only specified services are replaced
      expect(sl<FlutterSecureStorage>(), same(mockSecureStorage));
      expect(sl<SolidAuth>(), same(mockSolidAuth));

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
        mockSecureStorage.read(key: 'solid_auth_data'),
      ).thenAnswer((_) async => '{"key": "value"}');
      when(
        mockSecureStorage.read(key: 'solid_access_token'),
      ).thenAnswer((_) async => 'mock-access-token');
      mockJwtDecoderWrapper = MockJwtDecoderWrapper();
      when(mockJwtDecoderWrapper.decode(any)).thenReturn({
        'sub': 'https://example.org/profile/card#me',
        'exp': DateTime.now().add(Duration(days: 1)).millisecondsSinceEpoch,
      });
      // Configure SolidAuth mock to simulate successful token restoration
      mockSolidAuth = MockSolidAuth();

      // Create config with mocked services
      final config = ServiceLocatorConfig(
        httpClient: mockClient,
        providerService: mockProviderService,
        secureStorage: mockSecureStorage,
        solidAuth: mockSolidAuth,
        jwtDecoder: mockJwtDecoderWrapper,
        loggerService: mockLogger,
      );

      // Initialize with our config
      await initServiceLocator(config: config);

      // Verify the async service is ready and properly restored the session
      await sl.isReady<AuthService>();

      // Verify session data was correctly restored
      expect(sl<AuthService>().isAuthenticated, isTrue);
      expect(
        sl<AuthService>().currentWebId,
        equals('https://example.org/profile/card#me'),
      );
      expect(sl<AuthService>().podUrl, equals('https://example.org'));

      // Verify secure storage was queried for authentication data
      verify(mockSecureStorage.read(key: 'solid_webid')).called(1);
      verify(mockSecureStorage.read(key: 'solid_pod_url')).called(1);
      verify(mockSecureStorage.read(key: 'solid_auth_data')).called(1);
      verify(mockSecureStorage.read(key: 'solid_access_token')).called(1);
    });

    test('service locator can properly reset', () async {
      // Setup with a simple configuration
      final config = ServiceLocatorConfig(
        secureStorage: mockSecureStorage,
        loggerService: mockLogger,
      );

      await initServiceLocator(config: config);
      expect(sl.isRegistered<FlutterSecureStorage>(), isTrue);

      // Act - reset the service locator
      await sl.reset();

      // Verify - all registrations should be cleared
      expect(sl.isRegistered<FlutterSecureStorage>(), isFalse);
      expect(sl.isRegistered<AuthService>(), isFalse);
      expect(sl.isRegistered<ItemRepository>(), isFalse);
    });
  });
}
