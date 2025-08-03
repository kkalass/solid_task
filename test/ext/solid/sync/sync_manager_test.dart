import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/ext/solid/sync/sync_manager.dart';
import 'package:solid_task/ext/solid/sync/sync_service.dart';
import 'package:solid_task/ext/solid/sync/sync_state.dart';

import '../../../mocks/mock_auth_state_change_provider.dart';
@GenerateNiceMocks([
  MockSpec<SyncService>(),
  MockSpec<SolidAuthState>(),
  MockSpec<ContextLogger>(),
])
import 'sync_manager_test.mocks.dart';

void main() {
  group('SyncManager', () {
    late MockSyncService mockSyncService;
    late MockSolidAuthState mockSolidAuthState;
    late MockAuthStateChangeProvider mockAuthStateChangeProvider;
    late SyncManager syncManager;

    setUp(() {
      mockSyncService = MockSyncService();
      mockSolidAuthState = MockSolidAuthState();
      mockAuthStateChangeProvider = MockAuthStateChangeProvider();

      syncManager = SyncManager(
        mockSyncService,
        mockSolidAuthState,
        mockAuthStateChangeProvider,
      );
    });

    tearDown(() {
      syncManager.dispose();
    });

    test('initialize should start sync if already authenticated', () async {
      // Arrange
      when(mockSolidAuthState.isAuthenticated).thenReturn(true);
      when(mockSyncService.fullSync()).thenAnswer(
        (_) async =>
            SyncResult(success: true, itemsUploaded: 5, itemsDownloaded: 3),
      );

      // Act
      await syncManager.initialize();

      // Assert
      verify(mockSolidAuthState.isAuthenticated).called(1);
      verify(mockSyncService.fullSync()).called(1);
      expect(syncManager.currentStatus.state, equals(SyncState.synced));
    });

    test('initialize should not start sync if not authenticated', () async {
      // Arrange
      when(mockSolidAuthState.isAuthenticated).thenReturn(false);

      // Act
      await syncManager.initialize();

      // Assert
      verify(mockSolidAuthState.isAuthenticated).called(1);
      verifyNever(mockSyncService.fullSync());
    });

    test('startSynchronization should handle successful sync', () async {
      // Arrange
      when(mockSolidAuthState.isAuthenticated).thenReturn(true);
      when(mockSyncService.fullSync()).thenAnswer(
        (_) async =>
            SyncResult(success: true, itemsUploaded: 2, itemsDownloaded: 3),
      );

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
      when(mockSolidAuthState.isAuthenticated).thenReturn(true);
      when(mockSyncService.fullSync()).thenAnswer(
        (_) async => SyncResult(success: false, errorMessage: 'Network error'),
      );

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
      when(mockSolidAuthState.isAuthenticated).thenReturn(true);
      when(mockSyncService.fullSync()).thenThrow(Exception('Test exception'));

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
        mockSolidAuthState.isAuthenticated,
      ).thenReturn(true); // Add missing auth mock
      when(
        mockSyncService.syncToRemote(),
      ).thenAnswer((_) async => SyncResult(success: true, itemsUploaded: 2));

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
        mockAuthStateChangeProvider.emitAuthStateChange(false);
        when(mockSolidAuthState.isAuthenticated).thenReturn(false);

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
