import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:solid_task/ext/solid/auth/models/user_identity.dart';
import 'package:solid_task/ext/solid/sync/sync_manager.dart';
import 'package:solid_task/ext/solid/sync/sync_service.dart';
import 'package:solid_task/ext/solid/sync/sync_state.dart';
import 'package:solid_task/services/logger_service.dart';

import '../../../mocks/mock_solid_auth_state.dart';
@GenerateNiceMocks([MockSpec<SyncService>(), MockSpec<ContextLogger>()])
import 'sync_manager_test.mocks.dart';

UserIdentity createMockUserIdentity({
  String webId = 'https://alice.example.org/profile#me',
}) {
  return UserIdentity(webId: webId);
}

void main() {
  group('SyncManager', () {
    late MockSyncService mockSyncService;
    late MockSolidAuthState mockSolidAuthState;
    late SyncManager syncManager;

    setUp(() {
      mockSyncService = MockSyncService();
      mockSolidAuthState = MockSolidAuthState();

      syncManager = SyncManager(mockSyncService, mockSolidAuthState);
    });

    tearDown(() {
      syncManager.dispose();
    });

    test('initialize should start sync if already authenticated', () async {
      // Arrange

      when(mockSyncService.fullSync()).thenAnswer(
        (_) async =>
            SyncResult(success: true, itemsUploaded: 5, itemsDownloaded: 3),
      );
      mockSolidAuthState.emitAuthStateChange(createMockUserIdentity());

      // Act
      await syncManager.initialize();

      // Assert
      verify(mockSyncService.fullSync()).called(1);
      expect(syncManager.currentStatus.state, equals(SyncState.synced));
    });

    test('initialize should not start sync if not authenticated', () async {
      // Arrange

      // Act
      await syncManager.initialize();

      // Assert
      verifyNever(mockSyncService.fullSync());
    });

    test('startSynchronization should handle successful sync', () async {
      // Arrange
      when(mockSyncService.fullSync()).thenAnswer(
        (_) async =>
            SyncResult(success: true, itemsUploaded: 2, itemsDownloaded: 3),
      );
      mockSolidAuthState.emitAuthStateChange(createMockUserIdentity());

      // Act
      final result = await syncManager.startSynchronization();

      // Assert
      expect(result.success, isTrue);
      expect(result.itemsUploaded, equals(2));
      expect(result.itemsDownloaded, equals(3));
      expect(syncManager.currentStatus.state, equals(SyncState.synced));
      expect(syncManager.currentStatus.itemsUploaded, equals(2));
      expect(syncManager.currentStatus.itemsDownloaded, equals(3));
    });

    test('startSynchronization should handle failed sync', () async {
      // Arrange
      when(mockSyncService.fullSync()).thenAnswer(
        (_) async => SyncResult(success: false, errorMessage: 'Network error'),
      );
      mockSolidAuthState.emitAuthStateChange(createMockUserIdentity());

      // Act
      final result = await syncManager.startSynchronization();

      // Assert
      expect(result.success, isFalse);
      expect(result.errorMessage, equals('Network error'));
      expect(syncManager.currentStatus.state, equals(SyncState.error));
      expect(syncManager.currentStatus.error, equals('Network error'));
    });

    test('startSynchronization should handle exceptions', () async {
      // Arrange
      when(mockSyncService.fullSync()).thenThrow(Exception('Test exception'));
      mockSolidAuthState.emitAuthStateChange(createMockUserIdentity());

      // Act
      final result = await syncManager.startSynchronization();

      // Assert
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Exception: Test exception'));
      expect(syncManager.currentStatus.state, equals(SyncState.error));
      expect(
        syncManager.currentStatus.error,
        contains('Exception: Test exception'),
      );
    });

    test('syncToRemote should update status correctly', () async {
      // Arrange
      when(
        mockSyncService.syncToRemote(),
      ).thenAnswer((_) async => SyncResult(success: true, itemsUploaded: 2));
      mockSolidAuthState.emitAuthStateChange(createMockUserIdentity());

      // Act
      final result = await syncManager.syncToRemote();

      // Assert
      expect(result.success, isTrue);
      expect(result.itemsUploaded, equals(2));
      expect(syncManager.currentStatus.state, equals(SyncState.synced));
      expect(syncManager.currentStatus.itemsUploaded, equals(2));
    });

    test(
      'handleAuthStateChange should stop sync when not authenticated',
      () async {
        // Act
        // Arrange
        mockSolidAuthState.emitAuthStateChange(null);

        // Assert
        expect(syncManager.currentStatus.state, equals(SyncState.idle));
        verifyNever(mockSyncService.fullSync());
      },
    );

    test('dispose should clean up resources', () async {
      // Act
      syncManager.dispose();

      // Try to start sync after dispose
      try {
        await syncManager.startSynchronization();
      } catch (e) {
        // We expect an error because the stream is closed
      }

      // Assert - no calls to sync service
      verifyNever(mockSyncService.fullSync());
    });
  });
}
