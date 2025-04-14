import 'dart:async';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:solid_task/models/item_operation.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/storage/hive_backend.dart';
import 'package:solid_task/services/storage/operation_storage.dart';

/// Repository for storing and retrieving CRDT operations
class OperationRepository {
  late Box<dynamic> _box;
  final ContextLogger _logger;
  final HiveBackend<dynamic> _hiveBackend;
  
  bool _isInitialized = false;
  
  /// Stream controller for operation changes
  final StreamController<List<ItemOperation>> _operationsController = 
      StreamController<List<ItemOperation>>.broadcast();
      
  /// Private constructor
  OperationRepository._({
    HiveBackend<dynamic>? hiveBackend,
    LoggerService? loggerService,
  }) : _hiveBackend = hiveBackend ?? DefaultHiveBackend<dynamic>(),
       _logger = (loggerService ?? LoggerService()).createLogger(
         'OperationRepository',
       );
  
  /// Factory constructor for creating an initialized instance
  static Future<OperationRepository> create({
    HiveBackend<dynamic>? hiveBackend,
    LoggerService? loggerService,
  }) async {
    final instance = OperationRepository._(
      hiveBackend: hiveBackend,
      loggerService: loggerService,
    );
    await instance._init();
    return instance;
  }
  
  /// Initialize the repository
  Future<void> _init() async {
    if (_isInitialized) return;
    
    try {
      // Use OperationStorage to open the box
      // This class already handles Hive initialization
      _box = await OperationStorage.openOperationBox(
        hiveBackend: _hiveBackend,
      );
      
      _isInitialized = true;
      
      _initializeStream();
      _logger.debug('OperationRepository initialized successfully');
    } catch (e) {
      _logger.error('Failed to initialize OperationRepository', e);
      rethrow;
    }
  }
  
  /// Initialize the stream for changes
  void _initializeStream() {
    _operationsController.add(getAllOperations());
    
    // Watch Hive box changes
    _box.watch().listen((_) {
      if (!_operationsController.isClosed) {
        _operationsController.add(getAllOperations());
      }
    });
  }
  
  /// Check if the repository is initialized, throw if not
  void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'OperationRepository not initialized. Use create() factory first.',
      );
    }
  }
  
  /// Subscribe to operations stream
  Stream<List<ItemOperation>> watchOperations() {
    _checkInitialized();
    return _operationsController.stream;
  }
  
  /// Get all operations
  List<ItemOperation> getAllOperations() {
    _checkInitialized();
    final operations = <ItemOperation>[];
    for (final opJson in _box.values) {
      try {
        operations.add(ItemOperation.fromJson(Map<String, dynamic>.from(opJson)));
      } catch (e, stack) {
        _logger.error('Failed to parse operation', e, stack);
      }
    }
    return operations;
  }
  
  /// Get all operations for an item
  List<ItemOperation> getOperationsForItem(String itemId) {
    _checkInitialized();
    return getAllOperations()
        .where((op) => op.itemId == itemId)
        .toList();
  }
  
  /// Get unsynced operations for an item
  List<ItemOperation> getUnsyncedOperationsForItem(String itemId) {
    _checkInitialized();
    return getAllOperations()
        .where((op) => op.itemId == itemId && !op.isSynced)
        .toList();
  }
  
  /// Get all unsynced operations
  List<ItemOperation> getAllUnsyncedOperations() {
    _checkInitialized();
    return getAllOperations()
        .where((op) => !op.isSynced)
        .toList();
  }
  
  /// Save an operation
  Future<void> saveOperation(ItemOperation operation) async {
    _checkInitialized();
    await _box.put(operation.id, operation.toJson());
    _logger.debug('Saved operation: ${operation.id} for item ${operation.itemId}');
  }
  
  /// Save multiple operations
  Future<void> saveOperations(List<ItemOperation> operations) async {
    _checkInitialized();
    final batch = <String, Map<String, dynamic>>{};
    for (final op in operations) {
      batch[op.id] = op.toJson();
    }
    
    await _box.putAll(batch);
    _logger.debug('Saved ${operations.length} operations');
  }
  
  /// Mark operations as synced
  Future<void> markAsSynced(List<ItemOperation> operations) async {
    _checkInitialized();
    for (final op in operations) {
      op.isSynced = true;
      await _box.put(op.id, op.toJson());
    }
    _logger.debug('Marked ${operations.length} operations as synced');
  }
  
  /// Delete an operation
  Future<void> deleteOperation(String id) async {
    _checkInitialized();
    await _box.delete(id);
    _logger.debug('Deleted operation: $id');
  }
  
  /// Clean up operations for deleted items
  Future<void> cleanupOperationsForDeletedItems(List<String> activeItemIds) async {
    _checkInitialized();
    final allOperations = getAllOperations();
    final deletedOperations = allOperations
        .where((op) => !activeItemIds.contains(op.itemId) && op.isSynced)
        .toList();
    
    for (final op in deletedOperations) {
      await deleteOperation(op.id);
    }
    
    _logger.debug('Cleaned up ${deletedOperations.length} operations');
  }
  
  /// Release resources
  Future<void> close() async {
    if (_isInitialized) {
      try {
        await _operationsController.close();
        await _box.close();
        _isInitialized = false;
        _logger.debug('OperationRepository closed successfully');
      } catch (e, stack) {
        _logger.error('Error closing OperationRepository', e, stack);
      }
    }
  }
}