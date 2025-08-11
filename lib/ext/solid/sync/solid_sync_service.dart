import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';

import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/ext/solid/pod/storage/pod_storage_configuration.dart';
import 'package:solid_task/ext/solid/pod/storage/pod_storage_configuration_provider.dart';
import 'package:solid_task/ext/solid/sync/sync_service.dart';
import 'package:solid_task/ext/solid/sync/rdf_repository.dart';
import 'package:synchronized/synchronized.dart';

final _log = Logger("solid.sync");

/// Implementation of SyncService for SOLID pods that stores objects as RDF files
///
/// This service handles synchronization between a local repository and a SOLID pod.
/// It is domain-agnostic and works with any object types that can be mapped to/from RDF.
class SolidSyncService implements SyncService {
  final RdfRepository _repository;
  final SolidAuthState _solidAuthState;
  final SolidAuthOperations _solidAuthOperations;
  final http.Client _client;

  final RdfMapper _rdfMapper;
  final RdfCore _rdfCore;
  final PodStorageConfigurationProvider _configProvider;

  // Periodic sync
  Timer? _syncTimer;
  final Lock _syncLock = Lock();


  SolidSyncService({
    required RdfRepository repository,
    required SolidAuthState authState,
    required SolidAuthOperations authOperations,
    required http.Client client,
    required RdfMapper rdfMapper,
    required PodStorageConfigurationProvider configProvider,
    required RdfCore rdfCore,
  }) : _repository = repository,
       _solidAuthState = authState,
       _solidAuthOperations = authOperations,
       _client = client,
       _rdfMapper = rdfMapper,
       _configProvider = configProvider,
       _rdfCore = rdfCore;

  @override
  bool get isConnected =>
      _solidAuthState.isAuthenticated &&
      _configProvider.currentConfiguration != null;

  @override
  String? get userIdentifier => _solidAuthState.currentUser?.webId;

  /// Get the current pod storage configuration
  ///
  /// Returns null if not connected
  PodStorageConfiguration? get storageConfig =>
      _configProvider.currentConfiguration;

  @override
  Future<SyncResult> syncToRemote() async {
    final config = _configProvider.currentConfiguration;
    if (!isConnected || config == null) {
      return SyncResult.error('Not connected to SOLID pod');
    }

    try {
      _log.fine('Syncing objects to pod at ${config.storageRoot}');

      // Ensure container exists
      await _ensureContainerExists(config.appStorageRoot);

      // Get objects that need to be synced
      final objectsToSync = _repository.getAllSyncableObjects();

      if (objectsToSync.isEmpty) {
        _log.info('No objects to sync to remote');
        return SyncResult(success: true, itemsUploaded: 0);
      }

      _log.info('Syncing ${objectsToSync.length} objects to pod');

      // Convert objects to RDF graph
      final graph = _rdfMapper.graph.encodeObjects(objectsToSync);

      // Group triples by storage IRI using the strategy
      final triplesByStorageIri = config.storageStrategy.mapTriplesToStorage(
        graph,
      );
      int uploadedCount = 0;
      int errorCount = 0;
      // Upload each file
      for (final entry in triplesByStorageIri.entries) {
        try {
          final fileIri = entry.key;
          final fileUrl = Uri.parse(fileIri.iri);
          final triplesOfFile = entry.value;

          final codec = _rdfCore.codec(
            contentType: getContentTypeForFile(fileUrl.toString()),
          );

          final turtle = codec.encode(
            RdfGraph(triples: triplesOfFile),
            baseUri: fileUrl.toString(),
          );

          // Generate DPoP token for the request
          final dpop = _solidAuthOperations.generateDpopToken(
            fileUrl.toString(),
            'PUT',
          );
          final headers = {
            'Accept': '*/*',
            'Connection': 'keep-alive',
            'Content-Type': 'text/turtle',
            ...dpop.httpHeaders(),
          };
          // Send data to pod
          final response = await _client.put(
            fileUrl,
            headers: headers,
            body: turtle,
          );

          if (response.statusCode >= 200 && response.statusCode < 300) {
            uploadedCount++;
          } else {
            errorCount++;
            _log.warning(
              'Failed to sync file $fileUrl to pod with headers $headers  : ${response.statusCode} - ${response.body} - ${response.headers}',
            );
          }
        } catch (e, stackTrace) {
          errorCount++;
          _log.severe(
            'Error syncing file ${entry.key.iri} to pod',
            e,
            stackTrace,
          );
        }
      }
      if (uploadedCount > 0 && errorCount == 0) {
        _log.info(
          'Successfully synced $uploadedCount/${objectsToSync.length} objects to pod',
        );
      } else if (uploadedCount == 0 && errorCount == 0) {
        _log.fine('No objects to sync to pod');
      } else if (uploadedCount == 0 && errorCount > 0) {
        _log.warning(
          'Failed to sync $errorCount/${objectsToSync.length} objects to pod',
        );
        return SyncResult.error('Failed to sync $errorCount objects to pod');
      } else {
        _log.info(
          'Partially synced $uploadedCount/${objectsToSync.length} objects to pod with $errorCount errors',
        );
      }
      return SyncResult(
        success: true,
        itemsUploaded: uploadedCount,
        itemsUploadedFailed: errorCount,
      );
    } catch (e, stackTrace) {
      _log.severe('Error syncing to pod', e, stackTrace);
      return SyncResult.error('Error syncing to pod: $e');
    }
  }

  @override
  Future<SyncResult> syncFromRemote() async {
    final config = _configProvider.currentConfiguration;
    if (!isConnected || config == null) {
      return SyncResult.error('Not connected to SOLID pod');
    }

    try {
      _log.fine('Syncing from pod at ${config.storageRoot}');

      // Check if container exists
      if (!await _containerExists(config.appStorageRoot)) {
        _log.info('Container does not exist on pod yet');
        return SyncResult(success: true, itemsDownloaded: 0);
      }

      // List container contents to get all files
      final fileUrls = await _listContainerContents(config.appStorageRoot);
      final downloadedObjects = <Object>[];

      // Download and parse each file
      for (final fileUrl in fileUrls) {
        // Process all files - content type determined by HTTP headers

        try {
          // Generate DPoP token for the request
          final dPopToken = _solidAuthOperations.generateDpopToken(
            fileUrl,
            'GET',
          );

          // Get data from pod
          final response = await _client.get(
            Uri.parse(fileUrl),
            headers: {
              'Accept': 'text/turtle',
              'Connection': 'keep-alive',
              ...dPopToken.httpHeaders(),
            },
          );

          if (response.statusCode == 200) {
            // Parse the Turtle file
            final turtle = response.body;

            // Convert triples to domain objects using the mapper service
            // This is domain-agnostic as it relies on registered mappers
            final objects = _rdfMapper.decodeObjects<Object>(
              turtle,
              contentType: getContentTypeForFile(fileUrl),
              documentUrl: fileUrl,
            );

            downloadedObjects.addAll(objects);
            _log.fine(
              'Downloaded and parsed ${objects.length} objects from $fileUrl',
            );
          } else {
            _log.warning(
              'Failed to download file $fileUrl: ${response.statusCode} - ${response.body}',
            );
          }
        } catch (e, stackTrace) {
          _log.severe('Error processing file $fileUrl', e, stackTrace);
        }
      }

      // Import the downloaded objects
      if (downloadedObjects.isNotEmpty) {
        final mergedCount = await _repository.mergeObjects(downloadedObjects);
        _log.info('Merged $mergedCount objects from pod');

        return SyncResult(success: true, itemsDownloaded: mergedCount);
      }

      _log.info('No new objects found on pod');
      return SyncResult(success: true, itemsDownloaded: 0);
    } catch (e, stackTrace) {
      _log.severe('Error syncing from pod', e, stackTrace);
      return SyncResult.error('Error syncing from pod: $e');
    }
  }

  String getContentTypeForFile(String file) => 'text/turtle';

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

  @override
  void startPeriodicSync(Duration interval) {
    stopPeriodicSync();
    _syncTimer = Timer.periodic(interval, (_) async {
      await fullSync();
    });
    _log.info('Started periodic sync with interval: $interval');
  }

  @override
  void stopPeriodicSync() {
    if (_syncTimer != null) {
      _syncTimer!.cancel();
      _syncTimer = null;
      _log.info('Stopped periodic sync');
    }
  }

  @override
  void dispose() {
    stopPeriodicSync();
    _log.fine('Disposed SolidSyncService');
  }

  /// Test-only method to check if a sync timer is currently active
  bool get syncTimer => _syncTimer != null;

  /// Ensure that the container exists on the pod
  Future<void> _ensureContainerExists(String containerUrl) async {
    _log.fine('Ensuring container exists: $containerUrl');

    if (await _containerExists(containerUrl)) {
      _log.fine('Container already exists');
      return;
    }

    _log.fine('Container does not exist, creating it');

    try {
      // Generate DPoP token for the request
      final dPopToken = _solidAuthOperations.generateDpopToken(
        containerUrl,
        'PUT',
      );

      // Create container with proper LDP type
      final response = await _client.put(
        Uri.parse(containerUrl),
        headers: {
          'Content-Type': 'text/turtle',
          ...dPopToken.httpHeaders(),
          'Link': '<http://www.w3.org/ns/ldp#Container>; rel="type"',
        },
        body: '',
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        _log.severe(
          'Failed to create container: ${response.statusCode} - ${response.body}',
        );
        throw Exception(
          'Failed to create container: HTTP ${response.statusCode}',
        );
      }

      _log.info('Container created successfully');
    } catch (e, stackTrace) {
      _log.severe('Error creating container', e, stackTrace);
      rethrow;
    }
  }

  /// Check if a container exists on the pod
  ///
  /// Throws exceptions on network or authorization errors to allow proper error handling
  /// Returns true if the container exists (HTTP 200), false if it doesn't exist (HTTP 404)
  Future<bool> _containerExists(String containerUrl) async {
    try {
      // Generate DPoP token for the request
      final dPopToken = _solidAuthOperations.generateDpopToken(
        containerUrl,
        'HEAD',
      );

      // Check if container exists
      final response = await _client.head(
        Uri.parse(containerUrl),
        headers: {...dPopToken.httpHeaders()},
      );

      if (response.statusCode == 404) {
        return false;
      } else if (response.statusCode != 200) {
        _log.severe(
          'Unexpected status code checking container: ${response.statusCode}',
        );
        throw Exception('Unexpected HTTP status: ${response.statusCode}');
      }

      return true;
    } catch (e, stackTrace) {
      _log.severe('Error checking if container exists', e, stackTrace);
      // Propagate the exception instead of returning false
      rethrow;
    }
  }

  /// List the contents of a container
  Future<List<String>> _listContainerContents(String containerUrl) async {
    _log.fine('Listing container contents: $containerUrl');

    try {
      // Generate DPoP token for the request
      final dPopToken = _solidAuthOperations.generateDpopToken(
        containerUrl,
        'GET',
      );

      // Get container listing
      final response = await _client.get(
        Uri.parse(containerUrl),
        headers: {'Accept': 'text/turtle', ...dPopToken.httpHeaders()},
      );

      if (response.statusCode != 200) {
        _log.severe(
          'Failed to list container contents: ${response.statusCode} - ${response.body}',
        );
        throw Exception(
          'Failed to list container contents: HTTP ${response.statusCode}',
        );
      }

      // Parse the container listing (Turtle format)
      final turtle = response.body;
      final graph = _rdfCore.decode(
        turtle,
        contentType: 'text/turtle',
        documentUrl: containerUrl,
      );

      // Find all contains predicates to get resource URLs
      final containsPredicates = [
        IriTerm('http://www.w3.org/ns/ldp#contains'),
        IriTerm('http://www.w3.org/ns/ldp#resource'),
      ];

      final fileUrls = <String>{};

      for (final predicate in containsPredicates) {
        final triples = graph.findTriples(predicate: predicate);
        for (final triple in triples) {
          switch (triple.object) {
            case IriTerm iriTerm:
              // If the object is an IRI, add it directly
              fileUrls.add(iriTerm.iri);
              break;
            case BlankNodeTerm _:
              // If the object is a blank node, ignore it
              _log.warning('Container contains a blank node: ${triple.object}');
              break;
            case LiteralTerm _:
              // If the object is a literal, ignore it
              _log.warning('Container contains a literal: ${triple.object}');
              break;
          }
        }
      }

      _log.fine('Found ${fileUrls.length} files in container');
      return fileUrls.toList();
    } catch (e, stackTrace) {
      _log.severe('Error listing container contents', e, stackTrace);
      rethrow;
    }
  }
}
