import 'package:meta/meta.dart';
import 'package:solid_task/ext/solid/pod/storage/strategy/default_triple_storage_strategy.dart';
import 'package:solid_task/ext/solid/pod/storage/strategy/triple_storage_strategy.dart';

/// Defines storage configuration for a Solid Pod
///
/// Encapsulates all storage-related configuration including root paths
/// and storage strategy, providing a cohesive interface for Pod storage decisions.
@immutable
final class PodStorageConfiguration {
  /// Base storage root URL of the Pod (e.g., https://user.solidcommunity.net/)
  final String storageRoot;

  /// Optional application-specific subfolder within the storage root
  final String? appFolderRelPath;

  /// Strategy for mapping triples to storage locations
  final TripleStorageStrategy storageStrategy;

  /// Creates a pod storage configuration with the given parameters
  const PodStorageConfiguration({
    required this.storageRoot,
    this.appFolderRelPath,
    TripleStorageStrategy? storageStrategy,
  }) : storageStrategy =
           storageStrategy ?? const DefaultTripleStorageStrategy();

  /// The complete application storage root path (storageRoot + appFolderRelPath)
  ///
  /// Combines the storage root with the application folder path if specified,
  /// ensuring proper path separator handling.
  String get appStorageRoot {
    if (appFolderRelPath == null || appFolderRelPath!.isEmpty) {
      return storageRoot;
    }

    final normalizedRoot =
        storageRoot.endsWith('/') ? storageRoot : '$storageRoot/';
    final normalizedPath =
        appFolderRelPath!.startsWith('/')
            ? appFolderRelPath!.substring(1)
            : appFolderRelPath!;

    return '$normalizedRoot$normalizedPath';
  }

  /// Creates a new configuration with the same strategy but different root paths
  PodStorageConfiguration withStorageRoot({
    required String storageRoot,
    String? appFolderRelPath,
  }) => PodStorageConfiguration(
    storageRoot: storageRoot,
    appFolderRelPath: appFolderRelPath ?? this.appFolderRelPath,
    storageStrategy: storageStrategy,
  );

  /// Creates a new configuration with the same paths but a different strategy
  PodStorageConfiguration withStrategy(TripleStorageStrategy strategy) =>
      PodStorageConfiguration(
        storageRoot: storageRoot,
        appFolderRelPath: appFolderRelPath,
        storageStrategy: strategy,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PodStorageConfiguration &&
          runtimeType == other.runtimeType &&
          storageRoot == other.storageRoot &&
          appFolderRelPath == other.appFolderRelPath &&
          storageStrategy == other.storageStrategy;

  @override
  int get hashCode =>
      Object.hash(storageRoot, appFolderRelPath, storageStrategy);
}
