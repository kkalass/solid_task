import 'package:test/test.dart';
import 'package:solid_task/ext/solid/pod/storage/pod_storage_configuration.dart';
import 'package:solid_task/ext/solid/pod/storage/strategy/default_triple_storage_strategy.dart';
import 'package:solid_task/ext/solid/pod/storage/strategy/triple_storage_strategy.dart';

void main() {
  group('PodStorageConfiguration', () {
    final strategy = DefaultTripleStorageStrategy();

    test('should build appStorageRoot correctly without appFolderRelPath', () {
      final config = PodStorageConfiguration(
        storageRoot: 'https://pod.example.org/',
        storageStrategy: strategy,
      );

      expect(config.appStorageRoot, equals('https://pod.example.org/'));
    });

    test('should build appStorageRoot correctly with appFolderRelPath', () {
      final config = PodStorageConfiguration(
        storageRoot: 'https://pod.example.org/',
        appFolderRelPath: 'solidtask',
        storageStrategy: strategy,
      );

      expect(
        config.appStorageRoot,
        equals('https://pod.example.org/solidtask'),
      );
    });

    test('should handle slash prefix in appFolderRelPath', () {
      final config = PodStorageConfiguration(
        storageRoot: 'https://pod.example.org/',
        appFolderRelPath: '/solidtask',
        storageStrategy: strategy,
      );

      expect(
        config.appStorageRoot,
        equals('https://pod.example.org/solidtask'),
      );
    });

    test('should handle ending slash in storageRoot correctly', () {
      final config = PodStorageConfiguration(
        storageRoot: 'https://pod.example.org',
        appFolderRelPath: 'solidtask',
        storageStrategy: strategy,
      );

      expect(
        config.appStorageRoot,
        equals('https://pod.example.org/solidtask'),
      );
    });

    test('should create new config with different storage root', () {
      final originalConfig = PodStorageConfiguration(
        storageRoot: 'https://pod.example.org/',
        appFolderRelPath: 'solidtask',
        storageStrategy: strategy,
      );

      final newConfig = originalConfig.withStorageRoot(
        storageRoot: 'https://otherpod.example.com/',
      );

      expect(newConfig.storageRoot, equals('https://otherpod.example.com/'));
      expect(newConfig.appFolderRelPath, equals('solidtask'));
      expect(identical(newConfig.storageStrategy, strategy), isTrue);
    });

    test('should create new config with different strategy', () {
      final originalConfig = PodStorageConfiguration(
        storageRoot: 'https://pod.example.org/',
        appFolderRelPath: 'solidtask',
        storageStrategy: strategy,
      );

      final mockStrategy = _MockTripleStorageStrategy();
      final newConfig = originalConfig.withStrategy(mockStrategy);

      expect(newConfig.storageRoot, equals('https://pod.example.org/'));
      expect(newConfig.appFolderRelPath, equals('solidtask'));
      expect(identical(newConfig.storageStrategy, mockStrategy), isTrue);
    });
  });
}

// Simple mock for testing
class _MockTripleStorageStrategy implements TripleStorageStrategy {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
