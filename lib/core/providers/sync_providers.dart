import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solid_task/core/providers/auth_providers.dart';
import 'package:solid_task/core/providers/core_providers.dart';
import 'package:solid_task/core/providers/logger_providers.dart';
import 'package:solid_task/core/providers/repository_providers.dart';
import 'package:solid_task/services/sync/solid_sync_service.dart';
import 'package:solid_task/services/sync/sync_service.dart';

/// Provider for the sync service
final syncServiceProvider = Provider.autoDispose<SyncService>((ref) {
  try {
    return SolidSyncService(
      repository: ref.watch(baseItemRepositoryProvider),
      authOperations: ref.watch(solidAuthOperationsProvider),
      authState: ref.watch(solidAuthStateProvider),
      loggerService: ref.watch(loggerServiceProvider),
      client: ref.watch(httpClientProvider),
    );
  } catch (e) {
    // Handle initialization errors - these are likely due to dependencies 
    // that are still initializing
    throw StateError('Failed to initialize sync service: $e');
  }
});