import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/storage/hive_storage_service.dart';

// Import the mock classes from the existing test file
import '../../mocks/mock_temp_dir_path_provider.dart';
import 'hive_storage_service_test.dart' show MockBox, MockValueListenable;
import 'hive_storage_service_test.mocks.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group('HiveStorageService watchItems specialized tests', () {
    late MockHiveBackend<Item> mockHiveBackend;
    late MockBox<Item> mockBox;
    late MockValueListenable<Box<Item>> mockBoxListenable;
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
      mockBoxListenable = MockValueListenable<Box<Item>>(mockBox);

      // Set the value listener on the box
      mockBox.valueListenable = mockBoxListenable;

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
      storageService.refreshItems();

      // Wait for emission
      await Future.delayed(const Duration(milliseconds: 10));

      // Update the box with more items and trigger changes
      mockBox.valuesList = [item1, item2];
      storageService.refreshItems();

      await Future.delayed(const Duration(milliseconds: 10));

      mockBox.valuesList = [item1, item2, item3];
      storageService.refreshItems();

      // Allow time for all emissions to be processed
      await Future.delayed(const Duration(milliseconds: 50));

      // Clean up
      await subscription.cancel();

      // Verify emissions
      expect(
        emissions.length,
        greaterThanOrEqualTo(4),
        reason:
            'Should have at least 4 emissions: initial empty list + 3 updates',
      );

      // First emission may be empty list
      // Second emission should have item1
      expect(emissions[1].length, 1);
      expect(emissions[1][0].text, 'Item 1');

      // Third emission should have item1 and item2
      expect(emissions[2].length, 2);
      expect(emissions[2].map((i) => i.text).toList()..sort(), [
        'Item 1',
        'Item 2',
      ]);

      // Fourth emission should have all three items
      expect(emissions[3].length, 3);
      expect(emissions[3].map((i) => i.text).toList()..sort(), [
        'Item 1',
        'Item 2',
        'Item 3',
      ]);
    });

    test('watchItems emits updated list when items are deleted', () async {
      // Create test items
      final item1 = Item(text: 'Item 1', lastModifiedBy: 'client1');
      final item2 = Item(text: 'Item 2', lastModifiedBy: 'client1');

      // Add items to the box
      mockBox.valuesList = [item1, item2];
      storageService.refreshItems();

      // Get the stream and prepare to collect emissions
      final emissions = <List<Item>>[];
      final subscription = storageService.watchItems().listen(emissions.add);

      // Initial emission should have been received with both items
      await Future.delayed(const Duration(milliseconds: 10));

      // Remove one item
      mockBox.valuesList = [item2];
      storageService.refreshItems();

      // Wait for emission
      await Future.delayed(const Duration(milliseconds: 20));

      // Clean up
      await subscription.cancel();

      // Verify emissions
      expect(
        emissions.length,
        2,
        reason:
            'Should have 2 emissions: initial list + updated list after deletion',
      );

      // First emission should have both items
      expect(emissions[0].length, 2);

      // Second emission should only have item2
      expect(emissions[1].length, 1);
      expect(emissions[1][0].text, 'Item 2');
    });
  });
}
