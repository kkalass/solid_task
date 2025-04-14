import 'dart:convert';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/models/item_operation.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:solid_task/services/rdf/turtle/turtle_writer.dart';

/// Service for converting Items and Operations to RDF
class ItemRdfService {
  final ContextLogger _logger;
  
  static const String _itemNamespace = 'http://solid-task.org/items/ns#';
  static const String _crdtNamespace = 'http://solid-task.org/crdt/ns#';
  
  ItemRdfService({required ContextLogger logger}) : _logger = logger;
  
  /// Converts an Item and its operations to RDF
  RdfGraph itemToRdf(Item item, List<ItemOperation> operations) {
    _logger.debug('Converting item ${item.id} to RDF');
    
    final graph = RdfGraph();
    final itemUri = '${_itemNamespace}item/${item.id}';
    
    // Add item properties as RDF triples
    graph.addTriple(Triple(
      itemUri,
      '${_itemNamespace}text',
      item.text,
    ));
    
    graph.addTriple(Triple(
      itemUri,
      '${_itemNamespace}createdAt',
      item.createdAt.toIso8601String(),
    ));
    
    graph.addTriple(Triple(
      itemUri,
      '${_itemNamespace}isDeleted',
      item.isDeleted.toString(),
    ));
    
    graph.addTriple(Triple(
      itemUri,
      '${_itemNamespace}lastModifiedBy',
      item.lastModifiedBy,
    ));
    
    // Store vector clock as JSON
    graph.addTriple(Triple(
      itemUri,
      '${_crdtNamespace}vectorClock',
      jsonEncode(item.vectorClock),
    ));
    
    // Add CRDT operations
    for (var i = 0; i < operations.length; i++) {
      final operation = operations[i];
      final opId = '${_crdtNamespace}operation/${operation.id}';
      
      // Link item to operation
      graph.addTriple(Triple(
        itemUri,
        '${_crdtNamespace}hasOperation',
        opId,
      ));
      
      // Operation properties
      graph.addTriple(Triple(
        opId,
        '${_crdtNamespace}type',
        operation.type.toString().split('.').last,
      ));
      
      graph.addTriple(Triple(
        opId,
        '${_crdtNamespace}timestamp',
        operation.timestamp.toIso8601String(),
      ));
      
      graph.addTriple(Triple(
        opId,
        '${_crdtNamespace}clientId',
        operation.clientId,
      ));
      
      // Operation vector clock
      graph.addTriple(Triple(
        opId,
        '${_crdtNamespace}vectorClock',
        jsonEncode(operation.vectorClock),
      ));
      
      // Payload as JSON
      if (operation.payload.isNotEmpty) {
        graph.addTriple(Triple(
          opId,
          '${_crdtNamespace}payload',
          jsonEncode(operation.payload),
        ));
      }
      
      // Sync status
      graph.addTriple(Triple(
        opId,
        '${_crdtNamespace}isSynced',
        operation.isSynced.toString(),
      ));
    }
    
    return graph;
  }
  
  /// Converts an RDF graph back to an Item and its operations
  (Item, List<ItemOperation>) rdfToItem(RdfGraph graph, String itemId) {
    _logger.debug('Converting RDF to item $itemId');
    
    final itemUri = '${_itemNamespace}item/$itemId';
    
    // Extract item properties
    var textTriples = graph.findTriples(
      subject: itemUri,
      predicate: '${_itemNamespace}text',
    );
    
    var lastModifiedByTriples = graph.findTriples(
      subject: itemUri,
      predicate: '${_itemNamespace}lastModifiedBy',
    );
    
    if (textTriples.isEmpty || lastModifiedByTriples.isEmpty) {
      throw FormatException('Required properties missing for item $itemId');
    }
    
    // Create item
    final item = Item(
      text: textTriples.first.object,
      lastModifiedBy: lastModifiedByTriples.first.object,
    );
    
    // Set id explicitly
    item.id = itemId;
    
    // Set additional properties
    var createdAtTriples = graph.findTriples(
      subject: itemUri,
      predicate: '${_itemNamespace}createdAt',
    );
    
    if (createdAtTriples.isNotEmpty) {
      item.createdAt = DateTime.parse(createdAtTriples.first.object);
    }
    
    var isDeletedTriples = graph.findTriples(
      subject: itemUri,
      predicate: '${_itemNamespace}isDeleted',
    );
    
    if (isDeletedTriples.isNotEmpty) {
      item.isDeleted = isDeletedTriples.first.object.toLowerCase() == 'true';
    }
    
    // Parse vector clock from JSON
    var vectorClockTriples = graph.findTriples(
      subject: itemUri,
      predicate: '${_crdtNamespace}vectorClock',
    );
    
    if (vectorClockTriples.isNotEmpty) {
      final Map<String, dynamic> jsonMap = 
          jsonDecode(vectorClockTriples.first.object);
      item.vectorClock = jsonMap.map((k, v) => MapEntry(k, v as int));
    }
    
    // Extract operations
    final operations = <ItemOperation>[];
    final operationTriples = graph.findTriples(
      subject: itemUri,
      predicate: '${_crdtNamespace}hasOperation',
    );
    
    for (var triple in operationTriples) {
      final opUri = triple.object;
      
      // Extract operation properties
      var typeTriples = graph.findTriples(
        subject: opUri,
        predicate: '${_crdtNamespace}type',
      );
      
      var timestampTriples = graph.findTriples(
        subject: opUri,
        predicate: '${_crdtNamespace}timestamp',
      );
      
      var clientIdTriples = graph.findTriples(
        subject: opUri,
        predicate: '${_crdtNamespace}clientId',
      );
      
      var opVectorClockTriples = graph.findTriples(
        subject: opUri,
        predicate: '${_crdtNamespace}vectorClock',
      );
      
      var payloadTriples = graph.findTriples(
        subject: opUri,
        predicate: '${_crdtNamespace}payload',
      );
      
      var isSyncedTriples = graph.findTriples(
        subject: opUri,
        predicate: '${_crdtNamespace}isSynced',
      );
      
      if (typeTriples.isEmpty || clientIdTriples.isEmpty || opVectorClockTriples.isEmpty) {
        _logger.warning('Skipping operation with missing required properties: $opUri');
        continue;
      }
      
      // Parse operation type
      OperationType operationType;
      switch (typeTriples.first.object) {
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
          _logger.warning('Unknown operation type: ${typeTriples.first.object}');
          continue;
      }
      
      // Parse vector clock from JSON
      final Map<String, dynamic> vectorClockJson = 
          jsonDecode(opVectorClockTriples.first.object);
      final Map<String, int> vectorClock = 
          vectorClockJson.map((k, v) => MapEntry(k, v as int));
      
      // Parse payload from JSON
      Map<String, dynamic> payload = {};
      if (payloadTriples.isNotEmpty) {
        payload = jsonDecode(payloadTriples.first.object);
      }
      
      // Extract operation ID from URI
      final opId = opUri.split('/').last;
      
      // Parse timestamp
      DateTime timestamp = DateTime.now();
      if (timestampTriples.isNotEmpty) {
        timestamp = DateTime.parse(timestampTriples.first.object);
      }
      
      // Parse sync status
      bool isSynced = false;
      if (isSyncedTriples.isNotEmpty) {
        isSynced = isSyncedTriples.first.object.toLowerCase() == 'true';
      }
      
      // Create operation
      final operation = ItemOperation(
        id: opId,
        timestamp: timestamp,
        itemId: itemId,
        type: operationType,
        clientId: clientIdTriples.first.object,
        vectorClock: vectorClock,
        payload: payload,
        isSynced: isSynced,
      );
      
      operations.add(operation);
    }
    
    return (item, operations);
  }
  
  /// Converts an Item to Turtle format
  String itemToTurtle(Item item, List<ItemOperation> operations) {
    final graph = itemToRdf(item, operations);
    final writer = TurtleWriter();
    return writer.write(graph);
  }
}