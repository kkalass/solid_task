import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/storage/hive_backend.dart';
import 'package:solid_task/models/item_operation.dart';

/// Utility class for managing Hive boxes for CRDT operations
///
/// This class provides a centralized way to initialize and access
/// the Hive box used for storing operations, ensuring consistent
/// box names and initialization across the application.
class OperationStorage {
  static const String _operationsBoxName = 'operations';
  static bool _hiveInitialized = false;

  /// Opens the operations box, initializing Hive if necessary
  ///
  /// This method handles the initialization of Hive and registration
  /// of necessary adapters before opening the operations box.
  ///
  /// [hiveBackend] is the backend to use for Hive operations.
  /// If not provided, a default backend will be used.
  static Future<Box<dynamic>> openOperationBox({
    HiveBackend<dynamic>? hiveBackend,
    LoggerService? loggerService,
  }) async {
    final logger = (loggerService ?? LoggerService()).createLogger(
      'OperationStorage',
    );

    try {
      await _initHive(logger);

      final backend = hiveBackend ?? DefaultHiveBackend<dynamic>();
      final box = await backend.openBox(_operationsBoxName);

      logger.debug('Opened operations box successfully');
      return box;
    } catch (e, stack) {
      logger.error('Failed to open operations box', e, stack);
      rethrow;
    }
  }

  /// Initialize Hive if it hasn't been initialized yet
  static Future<void> _initHive(ContextLogger logger) async {
    if (_hiveInitialized) return;

    try {
      if (!kIsWeb) {
        final directory =
            await path_provider.getApplicationDocumentsDirectory();
        Hive.init(directory.path);
        logger.debug('Initialized Hive at ${directory.path}');
      }

      // Register the ItemOperation adapter if needed
      // Since we're using dynamic/Map storage for now, this isn't strictly necessary
      // but could be useful if we switch to typed boxes later

      _hiveInitialized = true;
      logger.debug('Hive initialized successfully');
    } catch (e, stack) {
      logger.error('Failed to initialize Hive', e, stack);
      rethrow;
    }
  }

  /// Close the operations box
  static Future<void> closeOperationBox(Box<dynamic> box) async {
    await box.close();
  }

  /// Delete all operations data (for testing or reset purposes)
  static Future<void> clearOperations(Box<dynamic> box) async {
    await box.clear();
  }
}
