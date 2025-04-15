import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solid_task/core/providers/repository_providers.dart';
import 'package:solid_task/core/providers/sync_manager_provider.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/repository/syncable_item_repository.dart';

/// Provider für das synchronisierbare Item-Repository
/// Dieses Repository dekoriert das Basis-Repository mit Sync-Funktionalität
final syncableItemRepositoryProvider = Provider.autoDispose<ItemRepository>((ref) {
  // Wir müssen den asynchronen SyncManager behandeln
  final syncManagerAsync = ref.watch(syncManagerProvider);
  
  return syncManagerAsync.when(
    data: (syncManager) => SyncableItemRepository(
      ref.watch(baseItemRepositoryProvider),
      syncManager,
    ),
    loading: () => ref.watch(baseItemRepositoryProvider), // Fallback zum Basis-Repository während der Initialisierung
    error: (error, stack) {
      // Bei Fehlern in der Sync-Initialisierung verwenden wir das Basis-Repository
      // und loggen den Fehler
      print('Fehler beim Initialisieren des SyncManagers: $error, verwende Basis-Repository');
      return ref.watch(baseItemRepositoryProvider);
    },
  );
});