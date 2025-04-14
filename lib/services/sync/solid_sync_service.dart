import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:solid_task/models/item.dart';
import 'package:solid_task/models/item_operation.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/item_rdf_service.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:solid_task/services/rdf/rdf_parser.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/repository/operation_repository.dart';
import 'package:solid_task/services/sync/sync_service.dart';
import 'package:synchronized/synchronized.dart';

/// Implementation of SyncService for SOLID pods using CRDT and RDF
class SolidSyncService implements SyncService {
  final ItemRepository _itemRepository;
  final OperationRepository _operationRepository;
  final SolidAuthState _solidAuthState;
  final SolidAuthOperations _solidAuthOperations;
  final http.Client _client;
  final ContextLogger _logger;
  final ItemRdfService _rdfService;
  final RdfParser _rdfParser;

  // Periodic sync
  Timer? _syncTimer;
  final Lock _syncLock = Lock();

  // Directory path constants
  static const String _itemsDirectory = 'items/';
  
  SolidSyncService({
    required ItemRepository repository,
    required OperationRepository operationRepository,
    required SolidAuthState authState,
    required SolidAuthOperations authOperations,
    required ContextLogger logger,
    required http.Client client,
    required ItemRdfService rdfService,
    required RdfParser rdfParser,
  }) : _itemRepository = repository,
       _operationRepository = operationRepository,
       _solidAuthState = authState,
       _solidAuthOperations = authOperations,
       _logger = logger,
       _client = client,
       _rdfService = rdfService,
       _rdfParser = rdfParser;

  @override
  bool get isConnected => _solidAuthState.isAuthenticated;

  @override
  String? get userIdentifier => _solidAuthState.currentUser?.webId;

  /// Get the base directory URL for items in the pod
  String? get _itemsDirectoryUrl {
    final podUrl = _solidAuthState.currentUser?.podUrl;
    if (podUrl == null) return null;
    return '$podUrl$_itemsDirectory';
  }
  
  /// Get the URL for a specific item in the pod
  String? _getItemUrl(String itemId) {
    final dirUrl = _itemsDirectoryUrl;
    if (dirUrl == null) return null;
    return '$dirUrl$itemId.ttl';
  }

  @override
  Future<SyncResult> syncToRemote() async {
    if (!isConnected) {
      return SyncResult.error('Not connected to SOLID pod');
    }

    final directoryUrl = _itemsDirectoryUrl;
    if (directoryUrl == null) {
      return SyncResult.error('Pod URL not available');
    }

    try {
      _logger.debug('Syncing items to pod at $directoryUrl');
      
      // Ensure the items directory exists
      await _ensureDirectory(directoryUrl);
      
      // Get all local items and their operations
      final items = _itemRepository.getAllItems();
      int uploadedItems = 0;
      
      // Process each item individually
      for (final item in items) {
        final itemUrl = _getItemUrl(item.id);
        if (itemUrl == null) continue;
        
        // Get unsynchronized operations for this item
        final operations = _operationRepository.getUnsyncedOperationsForItem(item.id);
        if (operations.isEmpty) continue;
        
        _logger.debug('Syncing item ${item.id} with ${operations.length} operations');
        
        // Convert item+operations to Turtle
        final turtleData = _rdfService.itemToTurtle(item, operations);
        
        // Check if file exists to determine HTTP method
        final exists = await _fileExists(itemUrl);
        
        if (exists) {
          // File exists, use PATCH for operations only
          await _patchItemOperations(itemUrl, item, operations);
        } else {
          // File doesn't exist, use PUT for the whole item
          await _putItemData(itemUrl, turtleData);
        }
        
        // Mark operations as synced
        await _operationRepository.markAsSynced(operations);
        uploadedItems++;
      }

      _logger.info('Successfully synced $uploadedItems items to pod');
      return SyncResult(success: true, itemsUploaded: uploadedItems);
    } catch (e, stackTrace) {
      _logger.error('Error syncing to pod', e, stackTrace);
      return SyncResult.error('Error syncing to pod: $e');
    }
  }
  
  /// Creates or ensures a directory exists on the pod
  Future<void> _ensureDirectory(String directoryUrl) async {
    try {
      // Check if directory exists
      final headResponse = await _client.head(
        Uri.parse(directoryUrl),
        headers: await _getAuthHeaders(directoryUrl, 'HEAD'),
      );
      
      if (headResponse.statusCode == 200) {
        // Directory exists
        return;
      }
      
      // Create the directory
      final response = await _client.put(
        Uri.parse(directoryUrl),
        headers: {
          ...await _getAuthHeaders(directoryUrl, 'PUT'),
          'Content-Type': 'text/turtle',
          'Link': '<http://www.w3.org/ns/ldp#BasicContainer>; rel="type"',
        },
      );
      
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception(
          'Failed to create directory: HTTP ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Error ensuring directory exists', e, stackTrace);
      rethrow;
    }
  }
  
  /// Checks if a file exists on the pod
  Future<bool> _fileExists(String url) async {
    try {
      final response = await _client.head(
        Uri.parse(url),
        headers: await _getAuthHeaders(url, 'HEAD'),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      _logger.debug('Error checking if file exists: $e');
      return false;
    }
  }
  
  /// Puts complete item data to the pod
  Future<void> _putItemData(String url, String turtleData) async {
    try {
      final response = await _client.put(
        Uri.parse(url),
        headers: {
          ...await _getAuthHeaders(url, 'PUT'),
          'Content-Type': 'text/turtle',
        },
        body: turtleData,
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Failed to put item data: HTTP ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Error putting item data', e, stackTrace);
      rethrow;
    }
  }
  
  /// Patches item operations using SPARQL Update
  Future<void> _patchItemOperations(
    String url, 
    Item item, 
    List<ItemOperation> operations,
  ) async {
    try {
      // Get existing RDF data first
      final existingData = await _getItemData(url);
      
      // Parse existing data
      final existingGraph = _rdfParser.parse(
        existingData,
        contentType: 'text/turtle',
        documentUrl: url,
      );
      
      // Generate SPARQL UPDATE to add new operations
      final sparqlUpdate = _generateSparlOperationInsert(item, operations);
      
      // Execute PATCH request
      final response = await _client.patch(
        Uri.parse(url),
        headers: {
          ...await _getAuthHeaders(url, 'PATCH'),
          'Content-Type': 'application/sparql-update',
        },
        body: sparqlUpdate,
      );
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Failed to patch operations: HTTP ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Error patching operations', e, stackTrace);
      rethrow;
    }
  }
  
  /// Generates SPARQL UPDATE statement to insert new operations
  String _generateSparlOperationInsert(Item item, List<ItemOperation> operations) {
    final buffer = StringBuffer();
    
    buffer.writeln('PREFIX crdt: <http://solid-task.org/crdt/ns#>');
    buffer.writeln('PREFIX item: <http://solid-task.org/items/ns#>');
    buffer.writeln('PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>');
    buffer.writeln();
    
    // Use INSERT DATA for operations
    buffer.writeln('INSERT DATA {');
    
    // Add operations
    for (final operation in operations) {
      final opUri = 'crdt:operation/${operation.id}';
      
      buffer.writeln('  item:item/${item.id} crdt:hasOperation $opUri .');
      buffer.writeln('  $opUri crdt:type "${operation.type.toString().split('.').last}" .');
      buffer.writeln('  $opUri crdt:timestamp "${operation.timestamp.toIso8601String()}"^^xsd:dateTime .');
      buffer.writeln('  $opUri crdt:clientId "${operation.clientId}" .');
      buffer.writeln('  $opUri crdt:vectorClock """${jsonEncode(operation.vectorClock)}""" .');
      
      if (operation.payload.isNotEmpty) {
        buffer.writeln('  $opUri crdt:payload """${jsonEncode(operation.payload)}""" .');
      }
      
      buffer.writeln('  $opUri crdt:isSynced "true"^^xsd:boolean .');
      buffer.writeln();
    }
    
    buffer.writeln('}');
    
    return buffer.toString();
  }

  /// Gets Turtle data for an item from the pod
  Future<String> _getItemData(String url) async {
    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: await _getAuthHeaders(url, 'GET'),
      );
      
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to get item data: HTTP ${response.statusCode} - ${response.body}',
        );
      }
      
      return response.body;
    } catch (e, stackTrace) {
      _logger.error('Error getting item data', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<SyncResult> syncFromRemote() async {
    if (!isConnected) {
      return SyncResult.error('Not connected to SOLID pod');
    }

    final directoryUrl = _itemsDirectoryUrl;
    if (directoryUrl == null) {
      return SyncResult.error('Pod URL not available');
    }

    try {
      _logger.debug('Syncing from pod at $directoryUrl');
      
      // First, check if the directory exists
      final dirExists = await _fileExists(directoryUrl);
      if (!dirExists) {
        _logger.info('Items directory does not exist on pod yet');
        return SyncResult(success: true, itemsDownloaded: 0);
      }
      
      // Get the directory listing
      final containerResponse = await _client.get(
        Uri.parse(directoryUrl),
        headers: {
          ...await _getAuthHeaders(directoryUrl, 'GET'),
          'Accept': 'text/turtle',
        },
      );
      
      if (containerResponse.statusCode != 200) {
        return SyncResult.error(
          'Failed to list items directory: HTTP ${containerResponse.statusCode}',
        );
      }
      
      // Parse the container as RDF to get file listings
      final containerGraph = _rdfParser.parse(
        containerResponse.body, 
        contentType: 'text/turtle',
        documentUrl: directoryUrl,
      );
      
      // Extract files from the container (looking for .ttl files)
      final itemUrls = _extractItemUrlsFromContainer(containerGraph, directoryUrl);
      
      int downloadedItems = 0;
      List<Item> remoteItems = [];
      List<ItemOperation> remoteOperations = [];
      
      // Process each item file
      for (final url in itemUrls) {
        try {
          final itemData = await _getItemData(url);
          final itemGraph = _rdfParser.parse(
            itemData, 
            contentType: 'text/turtle',
            documentUrl: url,
          );
          
          // Extract the item ID from the URL
          final itemId = url.split('/').last.replaceAll('.ttl', '');
          
          // Convert RDF to item and operations
          final (item, operations) = _rdfService.rdfToItem(itemGraph, itemId);
          
          remoteItems.add(item);
          remoteOperations.addAll(operations);
          downloadedItems++;
        } catch (e) {
          _logger.warning('Error processing item file $url: $e');
          // Continue with next file
        }
      }
      
      // Merge remote items with local items
      await _itemRepository.mergeItems(remoteItems);
      
      // Save remote operations, only if they don't exist locally
      final localOperations = _operationRepository.getAllOperations();
      final localOperationIds = localOperations.map((op) => op.id).toSet();
      
      final newOperations = remoteOperations
          .where((op) => !localOperationIds.contains(op.id))
          .toList();
      
      if (newOperations.isNotEmpty) {
        await _operationRepository.saveOperations(newOperations);
      }

      _logger.info(
        'Successfully synced $downloadedItems items from pod ' +
        '(${newOperations.length} new operations)',
      );
      
      return SyncResult(success: true, itemsDownloaded: downloadedItems);
    } catch (e, stackTrace) {
      _logger.error('Error syncing from pod', e, stackTrace);
      return SyncResult.error('Error syncing from pod: $e');
    }
  }
  
  /// Extracts item URLs from a container listing
  List<String> _extractItemUrlsFromContainer(RdfGraph graph, String containerUrl) {
    final results = <String>[];
    
    // Look for ldp:contains predicates
    final containsTriples = graph.findTriples(
      subject: containerUrl,
      predicate: 'http://www.w3.org/ns/ldp#contains',
    );
    
    for (var triple in containsTriples) {
      final url = triple.object;
      if (url.endsWith('.ttl')) {
        results.add(url);
      }
    }
    
    return results;
  }

  @override
  Future<SyncResult> fullSync() async {
    // Use a lock to prevent multiple syncs running at the same time
    return _syncLock.synchronized(() async {
      if (!isConnected) {
        return SyncResult.error('Not connected to SOLID pod');
      }

      // First sync from remote to get latest changes
      final downloadResult = await syncFromRemote();
      if (!downloadResult.success) {
        return downloadResult;
      }

      // Then sync local changes to remote
      final uploadResult = await syncToRemote();
      if (!uploadResult.success) {
        return uploadResult;
      }

      // Combine results
      return SyncResult(
        success: true,
        itemsDownloaded: downloadResult.itemsDownloaded,
        itemsUploaded: uploadResult.itemsUploaded,
      );
    });
  }
  
  /// Generate authentication headers for Solid Pod requests
  Future<Map<String, String>> _getAuthHeaders(String url, String method) async {
    final headers = <String, String>{
      'Accept': '*/*',
      'Connection': 'keep-alive',
    };
    
    final accessToken = _solidAuthState.authToken?.accessToken;
    if (accessToken != null) {
      final dPopToken = _solidAuthOperations.generateDpopToken(url, method);
      headers['Authorization'] = 'DPoP $accessToken';
      headers['DPoP'] = dPopToken;
    }
    
    return headers;
  }

  @override
  void startPeriodicSync(Duration interval) {
    stopPeriodicSync();
    _syncTimer = Timer.periodic(interval, (_) async {
      await fullSync();
    });
    _logger.info('Started periodic sync with interval: $interval');
  }

  @override
  void stopPeriodicSync() {
    if (_syncTimer != null) {
      _syncTimer!.cancel();
      _syncTimer = null;
      _logger.info('Stopped periodic sync');
    }
  }

  @override
  void dispose() {
    stopPeriodicSync();
    _logger.debug('Disposed SolidSyncService');
  }
}
