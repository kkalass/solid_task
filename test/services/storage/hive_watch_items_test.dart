import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/storage/hive_storage_service.dart';

// Import the mock classes from the existing test file
import '../../mocks/mock_temp_dir_path_provider.dart';
import 'hive_storage_service_test.dart' show MockBox;
import 'hive_storage_service_test.mocks.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group('HiveStorageService watchItems specialized tests', () {
    late MockHiveBackend<Item> mockHiveBackend;
    late MockBox<Item> mockBox;
    late HiveStorageService storageService;

    late MockTempDirPathProvider mockPathProvider;

    setUpAll(() {
      mockPathProvider = MockTempDirPathProvider(
        prefix: 'test_hive_storage_watch_items',
      );
      PathProviderPlatform.instance = mockPathProvider;
    });

    tearDownAll(() async {
      await mockPathProvider.cleanup();
    });

    setUp(() async {
      // Create mock objects in the correct order
      mockHiveBackend = MockHiveBackend<Item>();
      mockBox = MockBox<Item>();

      // Setup mock behavior
      when(mockHiveBackend.isAdapterRegistered(0)).thenReturn(false);
      when(mockHiveBackend.openBox('items')).thenAnswer((_) async => mockBox);

      // Create service with mocked backend
      storageService = await HiveStorageService.create(
        hiveBackend: mockHiveBackend,
      );
    });

    test('watchItems emits multiple updates when items change', () async {
      // Create test items
      final item1 = Item(text: 'Item 1', lastModifiedBy: 'client1');
      final item2 = Item(text: 'Item 2', lastModifiedBy: 'client1');
      final item3 = Item(text: 'Item 3', lastModifiedBy: 'client1');

      // Get the stream and prepare to collect emissions
      final emissions = <List<Item>>[];
      final subscription = storageService.watchItems().listen(emissions.add);

      // Initial emission should have been received
      await Future.delayed(const Duration(milliseconds: 10));
      expect(
        emissions.isNotEmpty,
        isTrue,
        reason: 'Should have received initial emission',
      );

      // Update the box with first item and trigger change
      mockBox.valuesList = [item1];

      // Trigger watch event
      mockBox.simulateBoxEvent(BoxEvent('key1', item1, false));

      // Wait for emission
      await Future.delayed(const Duration(milliseconds: 10));

      // Update the box with more items and trigger changes
      mockBox.valuesList = [item1, item2];

      // Trigger watch event
      mockBox.simulateBoxEvent(BoxEvent('key2', item2, false));

      await Future.delayed(const Duration(milliseconds: 10));

      mockBox.valuesList = [item1, item2, item3];

      // Trigger watch event
      mockBox.simulateBoxEvent(BoxEvent('key3', item3, false));

      await Future.delayed(const Duration(milliseconds: 10));

      // Verify we got all emissions - the exact number depends on the implementation
      // but we should at least get enough to contain all our state changes
      expect(emissions.length, greaterThanOrEqualTo(3));

      // Find the emission with one item (containing item1)
      expect(
        emissions.any((e) => e.length == 1 && e[0].text == 'Item 1'),
        isTrue,
        reason: 'Should find an emission with just item1',
      );

      // Find the emission with two items
      expect(
        emissions.any(
          (e) =>
              e.length == 2 &&
              e.map((i) => i.text).toSet().containsAll(['Item 1', 'Item 2']),
        ),
        isTrue,
        reason: 'Should find an emission with item1 and item2',
      );

      // Find the emission with three items
      expect(
        emissions.any(
          (e) =>
              e.length == 3 &&
              e.map((i) => i.text).toSet().containsAll([
                'Item 1',
                'Item 2',
                'Item 3',
              ]),
        ),
        isTrue,
        reason: 'Should find an emission with all three items',
      );

      // Clean up
      await subscription.cancel();
    });

    test('watchItems emits updated list when items are deleted', () async {
      // Create test items
      final item1 = Item(text: 'Item 1', lastModifiedBy: 'client1');
      final item2 = Item(text: 'Item 2', lastModifiedBy: 'client1');

      // Add items to the box
      mockBox.valuesList = [item1, item2];

      // Trigger watch event
      mockBox.simulateBoxEvent(BoxEvent('initialSetup', null, false));

      // Get the stream and prepare to collect emissions
      final emissions = <List<Item>>[];
      final subscription = storageService.watchItems().listen(emissions.add);

      // Initial emission should have been received with both items
      await Future.delayed(const Duration(milliseconds: 10));

      // Remove one item
      mockBox.valuesList = [item2];

      // Trigger watch event
      mockBox.simulateBoxEvent(BoxEvent('delete', item1, true));

      // Wait for emission
      await Future.delayed(const Duration(milliseconds: 20));

      // Clean up
      await subscription.cancel();

      // Verify emissions - number may vary based on implementation
      expect(
        emissions.length,
        greaterThanOrEqualTo(2),
        reason:
            'Should have at least 2 emissions: initial list + updated list after deletion',
      );

      // We should have an emission with both items
      expect(
        emissions.any(
          (e) =>
              e.length == 2 &&
              e.map((i) => i.text).toSet().containsAll(['Item 1', 'Item 2']),
        ),
        isTrue,
        reason: 'Should find an emission with both items',
      );

      // We should have an emission with only item2
      expect(
        emissions.any((e) => e.length == 1 && e[0].text == 'Item 2'),
        isTrue,
        reason: 'Should find an emission with only Item 2 after deletion',
      );
    });
  });
}
