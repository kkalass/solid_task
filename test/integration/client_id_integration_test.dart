import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:solid_task/bootstrap/service_locator.dart';
import 'package:solid_task/services/client_id_service.dart';
import 'package:solid_task/services/repository/item_repository.dart';

import '../bootstrap/service_locator_test.mocks.dart';
import '../mocks/mock_temp_dir_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Client ID Integration Tests', () {
    late MockFlutterSecureStorage mockSecureStorage;
    late MockTempDirPathProvider mockPathProvider;

    setUpAll(() {
      mockPathProvider = MockTempDirPathProvider(
        prefix: "test_client_id_integration",
      );
      PathProviderPlatform.instance = mockPathProvider;
    });
    tearDownAll(() async {
      await mockPathProvider.cleanup();
    });

    setUp(() {
      mockSecureStorage = MockFlutterSecureStorage();
    });

    tearDown(() async {
      await sl.reset();
    });

    test('should use consistent client ID for item creation', () async {
      // Arrange
      const expectedClientId = 'test-device-123';
      when(
        mockSecureStorage.read(key: 'device_client_id'),
      ).thenAnswer((_) async => expectedClientId);
      when(
        mockSecureStorage.read(key: 'solid_webid'),
      ).thenAnswer((_) async => null);
      when(
        mockSecureStorage.read(key: 'solid_pod_url'),
      ).thenAnswer((_) async => null);

      // Initialize service locator with mock secure storage
      await initServiceLocator(
        configure: (builder) {
          builder.withSecureStorageFactory((_) => mockSecureStorage);
        },
      );

      // Act
      final clientIdService = sl<ClientIdService>();
      final repository = sl<ItemRepository>();

      final retrievedClientId = await clientIdService.getClientId();
      final item = await repository.createItem('Test Task', retrievedClientId);

      // Assert
      expect(retrievedClientId, equals(expectedClientId));
      expect(item.lastModifiedBy, equals(expectedClientId));
      expect(item.vectorClock[expectedClientId], equals(1));
      expect(item.text, equals('Test Task'));
      expect(item.isDeleted, isFalse);

      // Verify secure storage was called for client ID
      verify(mockSecureStorage.read(key: 'device_client_id')).called(1);
    });

    test('should generate new client ID when none exists', () async {
      // Arrange
      when(
        mockSecureStorage.read(key: 'device_client_id'),
      ).thenAnswer((_) async => null);
      when(
        mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value')),
      ).thenAnswer((_) async {});
      when(
        mockSecureStorage.read(key: 'solid_webid'),
      ).thenAnswer((_) async => null);
      when(
        mockSecureStorage.read(key: 'solid_pod_url'),
      ).thenAnswer((_) async => null);

      // Initialize service locator
      await initServiceLocator(
        configure: (builder) {
          builder.withSecureStorageFactory((_) => mockSecureStorage);
        },
      );

      // Act
      final clientIdService = sl<ClientIdService>();
      final repository = sl<ItemRepository>();

      final clientId = await clientIdService.getClientId();
      final item = await repository.createItem('Generated ID Task', clientId);

      // Assert
      expect(clientId, isNotEmpty);
      expect(clientId.length, equals(36)); // UUID v4 length
      expect(item.lastModifiedBy, equals(clientId));
      expect(item.vectorClock[clientId], equals(1));

      // Verify secure storage interactions
      verify(mockSecureStorage.read(key: 'device_client_id')).called(1);
      verify(
        mockSecureStorage.write(key: 'device_client_id', value: clientId),
      ).called(1);
    });

    test('should use same client ID for multiple operations', () async {
      // Arrange
      when(
        mockSecureStorage.read(key: 'device_client_id'),
      ).thenAnswer((_) async => null);
      when(
        mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value')),
      ).thenAnswer((_) async {});
      when(
        mockSecureStorage.read(key: 'solid_webid'),
      ).thenAnswer((_) async => null);
      when(
        mockSecureStorage.read(key: 'solid_pod_url'),
      ).thenAnswer((_) async => null);

      // Initialize service locator
      await initServiceLocator(
        configure: (builder) {
          builder.withSecureStorageFactory((_) => mockSecureStorage);
        },
      );

      // Act
      final clientIdService = sl<ClientIdService>();
      final repository = sl<ItemRepository>();

      // Get client ID multiple times and create multiple items
      final clientId1 = await clientIdService.getClientId();
      final clientId2 = await clientIdService.getClientId();

      final item1 = await repository.createItem('Task 1', clientId1);
      final item2 = await repository.createItem('Task 2', clientId2);

      // Assert
      expect(clientId1, equals(clientId2));
      expect(item1.lastModifiedBy, equals(item2.lastModifiedBy));
      expect(
        item1.vectorClock.keys.first,
        equals(item2.vectorClock.keys.first),
      );

      // Should only read from storage once (cached after first call)
      verify(mockSecureStorage.read(key: 'device_client_id')).called(1);
      // Should only write once (when generating new ID)
      verify(
        mockSecureStorage.write(key: 'device_client_id', value: clientId1),
      ).called(1);
    });
  });
}
