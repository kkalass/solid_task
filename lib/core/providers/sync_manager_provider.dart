import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solid_task/core/providers/auth_providers.dart';
import 'package:solid_task/core/providers/logger_providers.dart';
import 'package:solid_task/core/providers/sync_providers.dart';
import 'package:solid_task/services/sync/sync_manager.dart';

/// Provider für den SyncManager, der die Synchronisierung zwischen lokalem Speicher und SOLID Pod orchestriert
/// FutureProvider wird verwendet, da die Initialisierung asynchron ist
final syncManagerProvider = FutureProvider.autoDispose<SyncManager>((ref) async {
  final syncManager = SyncManager(
    ref.watch(syncServiceProvider),
    ref.watch(solidAuthStateProvider),
    ref.watch(authStateChangeProvider),
    ref.watch(scopedLoggerProvider('SyncManager')),
  );
  
  // Initialize the sync manager
  await syncManager.initialize();
  
  // Ensure proper cleanup when the provider is disposed
  ref.onDispose(() {
    syncManager.dispose();
  });
  
  return syncManager;
});