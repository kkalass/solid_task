import 'package:uuid/uuid.dart';
import 'item.dart';

/// Typen von Operationen, die auf Items angewendet werden können
enum OperationType {
  create,
  update,
  delete,
}

/// Repräsentiert eine Operation im CRDT-System
/// Jede Operation ist idempotent und kann in beliebiger Reihenfolge angewendet werden
class ItemOperation {
  /// Eindeutige ID der Operation
  final String id;
  
  /// Zeitstempel der Operation
  final DateTime timestamp;
  
  /// ID des Items, auf das sich die Operation bezieht
  final String itemId;
  
  /// Typ der Operation
  final OperationType type;
  
  /// Clientidentifikator, der die Operation ausgeführt hat
  final String clientId;
  
  /// Zeitstempel im Vektoruhr-Format
  final Map<String, int> vectorClock;
  
  /// Payload der Operation, abhängig vom Typ
  final Map<String, dynamic> payload;
  
  /// Flag, das angibt, ob die Operation bereits mit dem Server synchronisiert wurde
  bool isSynced;

  /// Erstellt eine neue ItemOperation
  ItemOperation({
    String? id,
    DateTime? timestamp,
    required this.itemId,
    required this.type,
    required this.clientId,
    required this.vectorClock,
    required this.payload,
    this.isSynced = false,
  }) : 
    id = id ?? const Uuid().v4(),
    timestamp = timestamp ?? DateTime.now();
  
  /// Erstellt eine Create-Operation für ein Item
  factory ItemOperation.create(Item item) {
    return ItemOperation(
      itemId: item.id,
      type: OperationType.create,
      clientId: item.lastModifiedBy,
      vectorClock: Map.from(item.vectorClock),
      payload: {
        'text': item.text,
      },
    );
  }
  
  /// Erstellt eine Update-Operation für ein Item
  factory ItemOperation.update(Item item) {
    return ItemOperation(
      itemId: item.id,
      type: OperationType.update,
      clientId: item.lastModifiedBy,
      vectorClock: Map.from(item.vectorClock),
      payload: {
        'text': item.text,
      },
    );
  }
  
  /// Erstellt eine Delete-Operation für ein Item
  factory ItemOperation.delete(Item item) {
    return ItemOperation(
      itemId: item.id,
      type: OperationType.delete,
      clientId: item.lastModifiedBy,
      vectorClock: Map.from(item.vectorClock),
      payload: {},
    );
  }
  
  /// Wendet die Operation auf ein Item an
  Item applyTo(Item? item) {
    switch (type) {
      case OperationType.create:
        if (item != null) {
          // Wenn das Item bereits existiert, behandeln wir es wie ein Update
          return _applyUpdate(item);
        }
        return _createItem();
      case OperationType.update:
        if (item == null) {
          throw StateError('Cannot update non-existent item: $itemId');
        }
        return _applyUpdate(item);
      case OperationType.delete:
        if (item == null) {
          throw StateError('Cannot delete non-existent item: $itemId');
        }
        return _applyDelete(item);
    }
  }
  
  /// Erstellt ein neues Item aus dieser Create-Operation
  Item _createItem() {
    final item = Item(
      text: payload['text'],
      lastModifiedBy: clientId,
    );
    item.id = itemId;
    item.vectorClock = Map.from(vectorClock);
    
    return item;
  }
  
  /// Wendet die Update-Operation auf ein bestehendes Item an
  Item _applyUpdate(Item item) {
    // Wir wenden das Update nur an, wenn unsere Operation neuere Informationen hat
    bool shouldUpdate = false;
    
    // Überprüfen, ob diese Operation neuere Informationen hat
    for (final entry in vectorClock.entries) {
      final existingValue = item.vectorClock[entry.key] ?? 0;
      if (entry.value > existingValue) {
        shouldUpdate = true;
        break;
      }
    }
    
    if (shouldUpdate) {
      item.text = payload['text'];
      item.lastModifiedBy = clientId;
    }
    
    // Vektoruhr mergen, unabhängig davon, ob wir aktualisiert haben
    for (final entry in vectorClock.entries) {
      final existingValue = item.vectorClock[entry.key] ?? 0;
      if (entry.value > existingValue) {
        item.vectorClock[entry.key] = entry.value;
      }
    }
    
    return item;
  }
  
  /// Markiert ein Item als gelöscht
  Item _applyDelete(Item item) {
    // Wir löschen nur, wenn unsere Operation neuere Informationen hat
    bool shouldDelete = false;
    
    // Überprüfen, ob diese Operation neuere Informationen hat
    for (final entry in vectorClock.entries) {
      final existingValue = item.vectorClock[entry.key] ?? 0;
      if (entry.value > existingValue) {
        shouldDelete = true;
        break;
      }
    }
    
    if (shouldDelete) {
      item.isDeleted = true;
      item.lastModifiedBy = clientId;
    }
    
    // Vektoruhr mergen, unabhängig davon, ob wir gelöscht haben
    for (final entry in vectorClock.entries) {
      final existingValue = item.vectorClock[entry.key] ?? 0;
      if (entry.value > existingValue) {
        item.vectorClock[entry.key] = entry.value;
      }
    }
    
    return item;
  }
  
  /// Konvertiert die Operation in JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'itemId': itemId,
      'type': type.toString().split('.').last,
      'clientId': clientId,
      'vectorClock': vectorClock,
      'payload': payload,
      'isSynced': isSynced,
    };
  }
  
  /// Erstellt eine Operation aus JSON
  factory ItemOperation.fromJson(Map<String, dynamic> json) {
    OperationType operationType;
    switch (json['type']) {
      case 'create':
        operationType = OperationType.create;
        break;
      case 'update':
        operationType = OperationType.update;
        break;
      case 'delete':
        operationType = OperationType.delete;
        break;
      default:
        throw FormatException('Unknown operation type: ${json['type']}');
    }
    
    return ItemOperation(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      itemId: json['itemId'],
      type: operationType,
      clientId: json['clientId'],
      vectorClock: Map<String, int>.from(json['vectorClock']),
      payload: Map<String, dynamic>.from(json['payload']),
      isSynced: json['isSynced'] ?? false,
    );
  }
}