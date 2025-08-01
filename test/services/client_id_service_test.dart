import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:solid_task/services/client_id_service.dart';

import '../bootstrap/service_locator_test.mocks.dart';

void main() {
  group('DefaultClientIdService', () {
    late MockFlutterSecureStorage mockSecureStorage;
    late DefaultClientIdService clientIdService;

    setUp(() {
      mockSecureStorage = MockFlutterSecureStorage();
      clientIdService = DefaultClientIdService(
        secureStorage: mockSecureStorage,
      );
    });

    group('getClientId', () {
      test('should return cached client ID on subsequent calls', () async {
        // Arrange
        when(
          mockSecureStorage.read(key: 'device_client_id'),
        ).thenAnswer((_) async => 'test-client-id');

        // Act
        final firstCall = await clientIdService.getClientId();
        final secondCall = await clientIdService.getClientId();

        // Assert
        expect(firstCall, equals('test-client-id'));
        expect(secondCall, equals('test-client-id'));
        verify(mockSecureStorage.read(key: 'device_client_id')).called(1);
      });

      test('should load existing client ID from secure storage', () async {
        // Arrange
        const existingClientId = 'existing-client-id-123';
        when(
          mockSecureStorage.read(key: 'device_client_id'),
        ).thenAnswer((_) async => existingClientId);

        // Act
        final clientId = await clientIdService.getClientId();

        // Assert
        expect(clientId, equals(existingClientId));
        verify(mockSecureStorage.read(key: 'device_client_id')).called(1);
      });

      test('should generate new client ID when none exists', () async {
        // Arrange
        when(
          mockSecureStorage.read(key: 'device_client_id'),
        ).thenAnswer((_) async => null);
        when(
          mockSecureStorage.write(
            key: anyNamed('key'),
            value: anyNamed('value'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final clientId = await clientIdService.getClientId();

        // Assert
        expect(clientId, isNotEmpty);
        expect(clientId.length, equals(36)); // UUID v4 length
        verify(mockSecureStorage.read(key: 'device_client_id')).called(1);
        verify(
          mockSecureStorage.write(key: 'device_client_id', value: clientId),
        ).called(1);
      });

      test(
        'should generate new client ID when stored value is empty',
        () async {
          // Arrange
          when(
            mockSecureStorage.read(key: 'device_client_id'),
          ).thenAnswer((_) async => '');
          when(
            mockSecureStorage.write(
              key: anyNamed('key'),
              value: anyNamed('value'),
            ),
          ).thenAnswer((_) async {});

          // Act
          final clientId = await clientIdService.getClientId();

          // Assert
          expect(clientId, isNotEmpty);
          expect(clientId.length, equals(36)); // UUID v4 length
          verify(mockSecureStorage.read(key: 'device_client_id')).called(1);
          verify(
            mockSecureStorage.write(key: 'device_client_id', value: clientId),
          ).called(1);
        },
      );

      test('should cache generated client ID', () async {
        // Arrange
        when(
          mockSecureStorage.read(key: 'device_client_id'),
        ).thenAnswer((_) async => null);
        when(
          mockSecureStorage.write(
            key: anyNamed('key'),
            value: anyNamed('value'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final firstCall = await clientIdService.getClientId();
        final secondCall = await clientIdService.getClientId();

        // Assert
        expect(firstCall, equals(secondCall));
        verify(mockSecureStorage.read(key: 'device_client_id')).called(1);
        verify(
          mockSecureStorage.write(key: 'device_client_id', value: firstCall),
        ).called(1);
      });
    });

    group('regenerateClientId', () {
      test('should generate new client ID and store it', () async {
        // Arrange
        when(
          mockSecureStorage.write(
            key: anyNamed('key'),
            value: anyNamed('value'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final newClientId = await clientIdService.regenerateClientId();

        // Assert
        expect(newClientId, isNotEmpty);
        expect(newClientId.length, equals(36)); // UUID v4 length
        verify(
          mockSecureStorage.write(key: 'device_client_id', value: newClientId),
        ).called(1);
      });

      test('should update cached value after regeneration', () async {
        // Arrange
        when(
          mockSecureStorage.read(key: 'device_client_id'),
        ).thenAnswer((_) async => 'old-client-id');
        when(
          mockSecureStorage.write(
            key: anyNamed('key'),
            value: anyNamed('value'),
          ),
        ).thenAnswer((_) async {});

        // Get initial client ID to cache it
        final oldClientId = await clientIdService.getClientId();

        // Act
        final newClientId = await clientIdService.regenerateClientId();
        final cachedClientId = await clientIdService.getClientId();

        // Assert
        expect(oldClientId, equals('old-client-id'));
        expect(newClientId, isNot(equals(oldClientId)));
        expect(cachedClientId, equals(newClientId));
        // Only one read call should be made (for the initial getClientId)
        verify(mockSecureStorage.read(key: 'device_client_id')).called(1);
        verify(
          mockSecureStorage.write(key: 'device_client_id', value: newClientId),
        ).called(1);
      });
    });
  });
}
