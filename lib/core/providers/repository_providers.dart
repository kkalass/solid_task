import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solid_task/core/providers/logger_providers.dart';
import 'package:solid_task/core/providers/storage_providers.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/repository/solid_item_repository.dart';

/// Provider for the base item repository without sync capabilities
/// Uses Provider.autoDispose to ensure proper cleanup when the provider is no longer used
final baseItemRepositoryProvider = Provider.autoDispose<ItemRepository>((ref) {
  // We need to handle the async nature of the storage service
  final storageServiceAsync = ref.watch(localStorageServiceProvider);
  
  return storageServiceAsync.when(
    data: (storageService) => SolidItemRepository(
      storage: storageService,
      logger: ref.watch(scopedLoggerProvider('ItemRepository')),
    ),
    loading: () => throw StateError('Storage service is still initializing'),
    error: (error, stack) => throw StateError('Failed to initialize storage service: $error'),
  );
});