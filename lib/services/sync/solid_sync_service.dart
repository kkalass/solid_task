import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/item_rdf_serializer.dart';
import 'package:solid_task/services/rdf/mapping/rdf_mapper_service.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:solid_task/services/rdf/rdf_parser.dart';
import 'package:solid_task/services/rdf/rdf_serializer.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/sync/sync_service.dart';
import 'package:synchronized/synchronized.dart';

// FIXME KK - beware: we want to store the RDF graph based on the IRIs,
// e.g. we need to extract all subjects, group by the file urls (without fragment)
// and store in exactly those locations.
//
/// Implementation of SyncService for SOLID pods that stores items as individual Turtle RDF files
class SolidSyncService implements SyncService {
  final ItemRepository _repository;
  final SolidAuthState _solidAuthState;
  final SolidAuthOperations _solidAuthOperations;
  final http.Client _client;
  final ContextLogger _logger;
  final RdfMapperService _rdfMapperService;
  final RdfSerializerFactory _rdfSerializerFactory;
  final RdfParserFactory _rdfParserFactory;
  final String? _appFolderRelPath;

  // Periodic sync
  Timer? _syncTimer;
  final Lock _syncLock = Lock();

  // Container constants
  static const String _turtleExtension = '.ttl';

  SolidSyncService({
    required ItemRepository repository,
    required SolidAuthState authState,
    required SolidAuthOperations authOperations,
    required http.Client client,
    required RdfMapperService rdfMapperService,
    // for example solidtask - if set, then we will assume all files of the application to be underneath this within the storage root
    String? appFolderRelPath,
    LoggerService? loggerService,
    RdfSerializerFactory? rdfSerializerFactory,
    RdfParserFactory? rdfParserFactory,
  }) : _repository = repository,
       _appFolderRelPath = appFolderRelPath,
       _solidAuthState = authState,
       _solidAuthOperations = authOperations,
       _logger = (loggerService ?? LoggerService()).createLogger(
         'SolidSyncService',
       ),
       _client = client,
       _rdfSerializerFactory =
           rdfSerializerFactory ??
           RdfSerializerFactory(loggerService: loggerService),
       _rdfParserFactory =
           rdfParserFactory ?? RdfParserFactory(loggerService: loggerService),
       _rdfMapperService = rdfMapperService;

  @override
  bool get isConnected => _solidAuthState.isAuthenticated;

  @override
  String? get userIdentifier => _solidAuthState.currentUser?.webId;

  /// Get the container URL for the current user
  String? get _storageRoot {
    final podUrl = _solidAuthState.currentUser?.podUrl;
    return podUrl;
  }

  String get _appStorageRoot {
    return _storageRoot! + (_appFolderRelPath ?? '');
  }

  @override
  Future<SyncResult> syncToRemote() async {
    if (!isConnected) {
      return SyncResult.error('Not connected to SOLID pod');
    }

    final storageRoot = _storageRoot;
    if (storageRoot == null) {
      return SyncResult.error('Pod URL not available');
    }
    final appStorageRoot = _appStorageRoot;

    try {
      _logger.debug('Syncing items to pod at $storageRoot');

      // Ensure container exists
      await _ensureContainerExists(appStorageRoot);

      // FIXME KK - this does a full sync of all items everytime - is this smart?
      // Get all items
      final items = _repository.getAllItems();
      int uploadedCount = 0;

      final graph = _rdfMapperService.toGraphFromList(storageRoot, items);
      final triplesByStorageIri = graph.groupByStorageIri();

      // Upload each item as a separate RDF file
      for (final entry in triplesByStorageIri.entries) {
        try {
          final fileIri = entry.key;
          final fileUrl = fileIri.iri;
          final triplesOfFile = entry.value;

          final serializer = _rdfSerializerFactory.createSerializer(
            contentType: getContentTypeForFile(fileUrl),
          );

          final turtle = serializer.write(
            RdfGraph(triples: triplesOfFile),
            baseUri: appStorageRoot,
          );

          // Generate DPoP token for the request
          final dPopToken = _solidAuthOperations.generateDpopToken(
            fileUrl,
            'PUT',
          );

          // Send item to pod
          final response = await _client.put(
            Uri.parse(fileUrl),
            headers: {
              'Accept': '*/*',
              'Authorization': 'DPoP ${_solidAuthState.authToken?.accessToken}',
              'Connection': 'keep-alive',
              'Content-Type': 'text/turtle',
              'DPoP': dPopToken,
            },
            body: turtle,
          );

          if (response.statusCode != 200 && response.statusCode != 201) {
            _logger.warning(
              'Failed to sync item $fileUrl to pod: ${response.statusCode} - ${response.body}',
            );
          } else {
            uploadedCount++;
          }
        } catch (e, stackTrace) {
          _logger.error(
            'Error syncing item ${entry.key.iri} to pod',
            e,
            stackTrace,
          );
        }
      }

      _logger.info(
        'Successfully synced $uploadedCount/${items.length} items to pod',
      );
      return SyncResult(success: true, itemsUploaded: uploadedCount);
    } catch (e, stackTrace) {
      _logger.error('Error syncing to pod', e, stackTrace);
      return SyncResult.error('Error syncing to pod: $e');
    }
  }

  @override
  Future<SyncResult> syncFromRemote() async {
    if (!isConnected) {
      return SyncResult.error('Not connected to SOLID pod');
    }

    final storageRoot = _storageRoot;
    if (storageRoot == null) {
      return SyncResult.error('Pod URL not available');
    }
    final appStorageRoot = _appStorageRoot;
    try {
      _logger.debug('Syncing from pod at $storageRoot');

      // Check if container exists
      if (!await _containerExists(appStorageRoot)) {
        _logger.info('Tasks container does not exist on pod yet');
        return SyncResult(success: true, itemsDownloaded: 0);
      }

      // List container contents to get item files
      final fileUrls = await _listContainerContents(appStorageRoot);
      final downloadedItems = <Item>[];

      // Download and parse each item file
      for (final fileUrl in fileUrls) {
        // Skip non-Turtle files
        if (!fileUrl.endsWith(_turtleExtension)) continue;

        try {
          // Generate DPoP token for the request
          final dPopToken = _solidAuthOperations.generateDpopToken(
            fileUrl,
            'GET',
          );

          // Get item data from pod
          final response = await _client.get(
            Uri.parse(fileUrl),
            headers: {
              'Accept': 'text/turtle',
              'Authorization': 'DPoP ${_solidAuthState.authToken?.accessToken}',
              'Connection': 'keep-alive',
              'DPoP': dPopToken,
            },
          );

          if (response.statusCode == 200) {
            // Parse the Turtle file
            final turtle = response.body;
            final graph = _rdfParserFactory
                .createParser(contentType: getContentTypeForFile(fileUrl))
                .parse(turtle, documentUrl: fileUrl);

            /*
ok, hier habe ich ein kleines Problem: ich will den code ja eigentlich 
generisch halten und von referenzen auf SolidTask und spezifische Klassen
wie z. B. der Item Klasse befreien.

Beim serialisieren bin ich da schon relativ dicht dran, aber auch nicht
ganz sauber: ich frage immer noch eine Liste von items ab, die ich 
dann mappe. Das ist nicht ganz sauber im Sinne von dem, was ich hier erreichen
will. Aber der Rückweg gestaltet sich dann noch etwas schwieriger.

Anyways, ich hatte die Idee / den Plan, dass man diesen sync service mit
einem storage service verbinden kann. Diesem storage service kann man alle 
subjects abfragen die seit einer bestimmten Zeit geändert oder erstellt wurden
und diese in einen Graph umwandeln und auf dem Server persistieren.

auf dem Weg zurück wollte ich ähnlich vorgehen: alle Subjects abfragen die seit
dem letzten sync verändert wurden und die dann zurück wandeln und speichern.

Das hat aber noch ein paar probleme:

- Ich will hier eigentlich nichts über die konkreten Typen wissen, 
  muss das aber tun um die korrekte Umwandlung vornehmen zu können.
  Wobei: muss ich das? Ich kann ja auch im graph nach RdfConstants.typeIri 
  schauen und dann nach registrierten deserializern dafür gucken! Ich 
  könnte meinem RdfSubjectSerializer ja noch ein property geben,
  über welches der Typ raus gegeben werden muss - evtl. macht es auch
  Sinn, das entsprechende Triple dann automatisch zu erzeugen.

  Ok, das ist schonmal gut. Aber was mach ich dann zb. mit den vectorClock
  Einträgen? Die bekommen ja auch einen Typen, 


*/
            var allSubjects = _rdfMapperService.fromGraphAllSubjects(
              storageRoot,
              graph,
            );
            // FIXME KK - provide those to the repository for merging -
            // we should think more deeply on how the sync service and the repository
            // interact, especially if and where we use dart types.
            // IMHO this functionality needs to be application-agnostic.
            // The application should not worry about anything here - it should
            // simply instantiate the sync service, and be done.

            // Extract the item URI from the filename
            final itemId = _extractItemIdFromUrl(fileUrl);
            final itemUri = 'http://solidtask.org/tasks/$itemId';

            // Convert to Item
            final item = _rdfSerializer.rdfToItem(graph, itemUri);
            downloadedItems.add(item);
          } else {
            _logger.warning(
              'Failed to download item $fileUrl: ${response.statusCode} - ${response.body}',
            );
          }
        } catch (e, stackTrace) {
          _logger.error('Error processing item file $fileUrl', e, stackTrace);
        }
      }

      // Import the downloaded items
      if (downloadedItems.isNotEmpty) {
        await _repository.mergeItems(downloadedItems);
      }

      _logger.info(
        'Successfully synced ${downloadedItems.length} items from pod',
      );
      return SyncResult(success: true, itemsDownloaded: downloadedItems.length);
    } catch (e, stackTrace) {
      _logger.error('Error syncing from pod', e, stackTrace);
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

  /// Test-only method to check if a sync timer is currently active
  bool get syncTimer => _syncTimer != null;

  /// Ensure that the tasks container exists on the pod
  Future<void> _ensureContainerExists(String containerUrl) async {
    _logger.debug('Ensuring container exists: $containerUrl');

    if (await _containerExists(containerUrl)) {
      _logger.debug('Container already exists');
      return;
    }

    _logger.debug('Container does not exist, creating it');

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
          'Authorization': 'DPoP ${_solidAuthState.authToken?.accessToken}',
          'Content-Type': 'text/turtle',
          'DPoP': dPopToken,
          'Link': '<http://www.w3.org/ns/ldp#Container>; rel="type"',
        },
        body: '',
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        _logger.error(
          'Failed to create container: ${response.statusCode} - ${response.body}',
        );
        throw Exception(
          'Failed to create container: HTTP ${response.statusCode}',
        );
      }

      _logger.info('Container created successfully');
    } catch (e, stackTrace) {
      _logger.error('Error creating container', e, stackTrace);
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
        headers: {
          'Authorization': 'DPoP ${_solidAuthState.authToken?.accessToken}',
          'DPoP': dPopToken,
        },
      );

      if (response.statusCode == 404) {
        return false;
      } else if (response.statusCode != 200) {
        _logger.error(
          'Unexpected status code checking container: ${response.statusCode}',
        );
        throw Exception('Unexpected HTTP status: ${response.statusCode}');
      }

      return true;
    } catch (e, stackTrace) {
      _logger.error('Error checking if container exists', e, stackTrace);
      // Propagate the exception instead of returning false
      rethrow;
    }
  }

  /// List the contents of a container
  Future<List<String>> _listContainerContents(String containerUrl) async {
    _logger.debug('Listing container contents: $containerUrl');

    try {
      // Generate DPoP token for the request
      final dPopToken = _solidAuthOperations.generateDpopToken(
        containerUrl,
        'GET',
      );

      // Get container listing
      final response = await _client.get(
        Uri.parse(containerUrl),
        headers: {
          'Accept': 'text/turtle',
          'Authorization': 'DPoP ${_solidAuthState.authToken?.accessToken}',
          'DPoP': dPopToken,
        },
      );

      if (response.statusCode != 200) {
        _logger.error(
          'Failed to list container contents: ${response.statusCode} - ${response.body}',
        );
        throw Exception(
          'Failed to list container contents: HTTP ${response.statusCode}',
        );
      }

      // Parse the container listing (Turtle format)
      final turtle = response.body;
      final graph = _rdfParserFactory
          .createParser(contentType: 'text/turtle')
          .parse(turtle, documentUrl: containerUrl);

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
              _logger.warning(
                'Container contains a blank node: ${triple.object}',
              );
              break;
            case LiteralTerm _:
              // If the object is a literal, ignore it
              _logger.warning('Container contains a literal: ${triple.object}');
              break;
          }
        }
      }

      _logger.debug('Found ${fileUrls.length} files in container');
      return fileUrls.toList();
    } catch (e, stackTrace) {
      _logger.error('Error listing container contents', e, stackTrace);
      rethrow;
    }
  }

  /// Extract item ID from a file URL
  String _extractItemIdFromUrl(String fileUrl) {
    final uri = Uri.parse(fileUrl);
    final pathSegments = uri.pathSegments;

    // Get the filename
    if (pathSegments.isEmpty) {
      throw FormatException('Invalid file URL: $fileUrl');
    }

    final filename = pathSegments.last;

    // Remove the .ttl extension
    if (!filename.endsWith(_turtleExtension)) {
      throw FormatException('Not a Turtle file: $fileUrl');
    }

    return filename.substring(0, filename.length - _turtleExtension.length);
  }
}
