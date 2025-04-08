import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:flutter/foundation.dart' show kIsWeb, VoidCallback;
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';
import 'dart:async';
import 'dart:io' show FileSystemException;

/// Hive implementation of the local storage service
class HiveStorageService implements LocalStorageService {
  static const String _boxName = 'items';
  Box<Item>? _box;
  bool _isInitialized = false;
  final int _maxRetries = 5;
  final Duration _retryDelay = Duration(milliseconds: 200);

  @override
  Future<void> init() async {
    if (_isInitialized) return;

    // Initialize Hive
    if (kIsWeb) {
      await Hive.initFlutter();
    } else {
      final appDocumentDir =
          await path_provider.getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDocumentDir.path);
    }

    // Register Hive adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ItemAdapter());
    }

    // Open box with retry mechanism
    _box = await _openBoxWithRetry(_maxRetries);
    _isInitialized = true;
  }

  /// Open Hive box with a retry mechanism to handle lock conflicts
  Future<Box<Item>> _openBoxWithRetry(int retriesLeft) async {
    try {
      // Try to open the box normally
      return await Hive.openBox<Item>(_boxName);
    } on FileSystemException catch (e) {
      // If it's a lock issue and we still have retries left
      if (e.message.contains('lock failed') && retriesLeft > 0) {
        // Close any potentially open instances first
        await Hive.close();

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
    return _box!.values.toList();
  }

  @override
  Item? getItem(String id) {
    _checkInitialized();
    return _box!.get(id);
  }

  @override
  Future<void> saveItem(Item item) async {
    _checkInitialized();
    await _box!.put(item.id, item);
  }

  @override
  Future<void> deleteItem(String id) async {
    _checkInitialized();
    await _box!.delete(id);
  }

  @override
  Stream<List<Item>> watchItems() {
    _checkInitialized();

    // Create a StreamController to convert ValueListenable to Stream
    final controller = StreamController<List<Item>>.broadcast();

    // Add current values immediately
    controller.add(_box!.values.toList());

    // Listen for changes and add new values to the stream
    VoidCallback? listener;
    listener = () {
      if (!controller.isClosed) {
        controller.add(_box!.values.toList());
      }
    };

    final listenable = _box!.listenable();
    listenable.addListener(listener);

    // Clean up when the stream is canceled
    controller.onCancel = () {
      if (listener != null) {
        listenable.removeListener(listener);
      }
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<void> close() async {
    if (_isInitialized && _box != null) {
      try {
        await _box!.close();
      } catch (e) {
        // Log error but don't crash if closing fails
        print('Error closing Hive box: $e');
      } finally {
        _isInitialized = false;
        _box = null;
      }
    }
  }

  void _checkInitialized() {
    if (!_isInitialized || _box == null) {
      throw StateError(
        'HiveStorageService not initialized. Call init() first.',
      );
    }
  }
}
