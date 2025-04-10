import 'dart:async';
import 'dart:io' show FileSystemException;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/storage/hive_backend.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';

/// Implementation of LocalStorageService using Hive
class HiveStorageService implements LocalStorageService {
  static const String _boxName = 'items';
  late Box<Item> _box;
  final StreamController<List<Item>> _itemsController =
      StreamController<List<Item>>.broadcast();
  bool _isInitialized = false;
  final int _maxRetries = 5;
  final Duration _retryDelay = Duration(milliseconds: 200);
  final ContextLogger _logger;

  // Injected dependency for Hive operations
  final HiveBackend<Item> _hiveBackend;

  /// Creates a new HiveStorageService with optional backend
  HiveStorageService._({
    HiveBackend<Item>? hiveBackend,
    LoggerService? loggerService,
  }) : _hiveBackend = hiveBackend ?? DefaultHiveBackend<Item>(),
       _logger = (loggerService ?? LoggerService()).createLogger(
         'HiveStorageService',
       );

  /// Factory constructor to create a singleton instance
  static Future<HiveStorageService> create({
    HiveBackend<Item>? hiveBackend,
    LoggerService? loggerService,
  }) async {
    var instance = HiveStorageService._(hiveBackend: hiveBackend);
    await instance._init();
    return instance;
  }

  Future<void> _init() async {
    if (_isInitialized) return;

    // Initialize Hive
    if (kIsWeb) {
      await _hiveBackend.initFlutter();
    } else {
      final appDocumentDir =
          await path_provider.getApplicationDocumentsDirectory();
      await _hiveBackend.initFlutter(appDocumentDir.path);
    }

    // Register Hive adapters if not already registered
    if (!_hiveBackend.isAdapterRegistered(0)) {
      // Use the automatically generated adapter from item.g.dart
      _hiveBackend.registerAdapter(ItemAdapter());
    }

    // Open box with retry mechanism
    _box = await _openBoxWithRetry(_maxRetries);
    _isInitialized = true;

    // Setup box change listener
    _box.listenable().addListener(_onBoxChanged);

    // Emit initial items
    _itemsController.add(getAllItems());
  }

  void _onBoxChanged() {
    if (!_itemsController.isClosed) {
      _itemsController.add(getAllItems());
    }
  }

  /// Manually triggers a refresh of the items stream
  /// This is primarily useful for testing
  void refreshItems() {
    _onBoxChanged();
  }

  /// Open Hive box with a retry mechanism to handle lock conflicts
  Future<Box<Item>> _openBoxWithRetry(int retriesLeft) async {
    try {
      // Try to open the box normally
      return await _hiveBackend.openBox(_boxName);
    } on FileSystemException catch (e) {
      // If it's a lock issue and we still have retries left
      if (e.message.contains('lock failed') && retriesLeft > 0) {
        // Close any potentially open instances first
        await _hiveBackend.closeBoxes();

        // Wait a bit before retrying
        await Future.delayed(_retryDelay);

        // Try again with one fewer retry
        return _openBoxWithRetry(retriesLeft - 1);
      } else {
        // If we're out of retries or it's a different error, rethrow
        rethrow;
      }
    }
  }

  @override
  List<Item> getAllItems() {
    _checkInitialized();
    return _box.values.toList();
  }

  @override
  Item? getItem(String id) {
    _checkInitialized();
    return _box.get(id);
  }

  @override
  Future<void> saveItem(Item item) async {
    _checkInitialized();
    await _box.put(item.id, item);
  }

  @override
  Future<void> deleteItem(String id) async {
    _checkInitialized();
    await _box.delete(id);
  }

  @override
  Stream<List<Item>> watchItems() {
    _checkInitialized();

    // Create a broadcast controller that emits current state when someone subscribes
    StreamController<List<Item>>? controller;
    StreamSubscription<List<Item>>? subscription;

    controller = StreamController<List<Item>>.broadcast(
      onListen: () {
        // Immediately emit the current state when first listener subscribes
        if (subscription == null) {
          controller!.add(getAllItems());

          // Listen for future updates
          subscription = _itemsController.stream.listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
          );
        }
      },
      onCancel: () {
        // Only clean up when the last listener unsubscribes
        if (!controller!.hasListener) {
          subscription?.cancel();
          subscription = null;
        }
      },
    );

    return controller.stream;
  }

  @override
  Future<void> close() async {
    if (_isInitialized) {
      try {
        await _box.close();
        await _itemsController.close();
        await _hiveBackend.closeBoxes();
      } catch (e, stackTrace) {
        // Log error but don't crash if closing fails
        _logger.error('Error closing Hive box: ', e, stackTrace);
      } finally {
        _isInitialized = false;
      }
    }
  }

  void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'HiveStorageService not initialized. Call init() first.',
      );
    }
  }
}
