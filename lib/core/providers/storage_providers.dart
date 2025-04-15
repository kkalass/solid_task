import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solid_task/core/providers/logger_providers.dart';
import 'package:solid_task/services/storage/hive_storage_service.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';

/// Provider for local storage service
/// Uses FutureProvider because initialization is asynchronous
final localStorageServiceProvider = FutureProvider<LocalStorageService>((ref) async {
  return HiveStorageService.create(loggerService: ref.watch(loggerServiceProvider));
});