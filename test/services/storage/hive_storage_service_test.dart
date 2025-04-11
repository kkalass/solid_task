import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/storage/hive_backend.dart';
import 'package:solid_task/services/storage/hive_storage_service.dart';

// Generate mock for HiveBackend only (we'll handle Box manually)
import '../../mocks/mock_temp_dir_path_provider.dart';
@GenerateMocks([HiveBackend])
import 'hive_storage_service_test.mocks.dart';

// Custom mock implementation for Box to handle extension methods
class MockBox<T> extends Mock implements Box<T> {
  final StreamController<BoxEvent> _watchController =
      StreamController<BoxEvent>.broadcast();
  List<T> _values = [];
  final Map<dynamic, T> _items = {};

  MockBox();

  // Add a setter for values to allow updating the list in tests
  set valuesList(List<T> newValues) {
    _values = newValues;
  }

  @override
  Stream<BoxEvent> watch({dynamic key}) {
    return _watchController.stream;
  }

  // Helper to simulate box events
  void simulateBoxEvent(BoxEvent event) {
    _watchController.add(event);
  }

  // Override these methods to ensure they can be verified with Mockito
  @override
  T? get(dynamic key, {T? defaultValue}) {
    return super.noSuchMethod(
      Invocation.method(#get, [key], {#defaultValue: defaultValue}),
      returnValueForMissingStub: _items[key] ?? defaultValue,
    );
  }

  @override
  Future<void> put(dynamic key, T value) {
    _items[key] = value;
    super.noSuchMethod(Invocation.method(#put, [key, value]));
    return Future<void>.value();
  }

  @override
  Future<void> delete(dynamic key) {
    _items.remove(key);
    super.noSuchMethod(Invocation.method(#delete, [key]));
    return Future<void>.value();
  }

  @override
  Future<void> close() {
    _watchController.close();
    super.noSuchMethod(Invocation.method(#close, []));
    return Future<void>.value();
  }

  // Implementation of values getter
  @override
  Iterable<T> get values => _values;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  group('HiveStorageService', () {
    // Test variables
    late MockHiveBackend<Item> mockHiveBackend;
    late MockBox<Item> mockBox;
    late HiveStorageService storageService;

    late MockTempDirPathProvider mockPathProvider;

    setUpAll(() {
      mockPathProvider = MockTempDirPathProvider(prefix: 'test_hive_storage');
      PathProviderPlatform.instance = mockPathProvider;
    });

    tearDownAll(() async {
      await mockPathProvider.cleanup();
    });

    setUp(() async {
      // Create mock objects in the correct order to avoid circular dependency issues
      mockHiveBackend = MockHiveBackend<Item>();

      // First create the box
      mockBox = MockBox<Item>();

      // Setup mock behavior
      when(mockHiveBackend.isAdapterRegistered(0)).thenReturn(false);
      when(mockHiveBackend.openBox('items')).thenAnswer((_) async => mockBox);

      // Create service with mocked backend
      storageService = await HiveStorageService.create(
        hiveBackend: mockHiveBackend,
      );
    });

    test('init registers adapter and opens box', () async {
      // Assert
      verify(mockHiveBackend.isAdapterRegistered(0)).called(1);
      verify(mockHiveBackend.registerAdapter(any)).called(1);
      verify(mockHiveBackend.openBox('items')).called(1);

      // Since listenable() is now a direct method, we can verify it was called
      // but we don't use verify() since it's not a mock method
    });

    test('getAllItems returns all items from box', () async {
      // Arrange
      final items = [
        Item(text: 'item1', lastModifiedBy: 'user1'),
        Item(text: 'item2', lastModifiedBy: 'user2'),
      ];
      // Use the setter instead of when()
      mockBox.valuesList = items;

      // Act
      final result = storageService.getAllItems();

      // Assert
      expect(result, equals(items));
    });

    test('getItem returns item by id', () async {
      // Arrange
      final item = Item(text: 'test', lastModifiedBy: 'user');
      when(mockBox.get('123')).thenReturn(item);
      when(mockBox.get('not-found')).thenReturn(null);

      // Act & Assert
      expect(storageService.getItem('123'), equals(item));
      expect(storageService.getItem('not-found'), isNull);
      verify(mockBox.get('123')).called(1);
      verify(mockBox.get('not-found')).called(1);
    });

    test('saveItem puts item in box', () async {
      // Arrange
      final item = Item(text: 'new item', lastModifiedBy: 'user');

      // Act
      await storageService.saveItem(item);

      // Assert
      verify(mockBox.put(item.id, item)).called(1);
    });

    test('deleteItem removes item from box', () async {
      // Arrange
      const itemId = 'item-to-delete';

      // Act
      await storageService.deleteItem(itemId);

      // Assert
      verify(mockBox.delete(itemId)).called(1);
    });

    test('watchItems emits items when box changes', () async {
      // Arrange - create a new service for this test with controlled emissions
      final testHiveBackend = MockHiveBackend<Item>();
      final testBox = MockBox<Item>();

      when(testHiveBackend.isAdapterRegistered(0)).thenReturn(false);
      when(testHiveBackend.openBox('items')).thenAnswer((_) async => testBox);

      // Set up initial items
      final items1 = [Item(text: 'initial', lastModifiedBy: 'user')];
      testBox.valuesList = items1;

      // Create and initialize service
      final testService = await HiveStorageService.create(
        hiveBackend: testHiveBackend,
      );

      // Set up a completer to track the second emission
      final secondEmission = Completer<List<Item>>();
      bool firstEmissionReceived = false;

      // Subscribe to the stream once with a listener that handles both emissions
      final subscription = testService.watchItems().listen((data) {
        if (!firstEmissionReceived) {
          // This is the first emission
          expect(
            data,
            equals(items1),
            reason: 'First emission should match initial items',
          );
          firstEmissionReceived = true;
        } else {
          // This is the second emission
          secondEmission.complete(data);
        }
      });

      // Wait a short time to ensure the first emission has been processed
      await Future.delayed(const Duration(milliseconds: 10));

      // Verify first emission was received
      expect(
        firstEmissionReceived,
        isTrue,
        reason: 'First emission should have been received',
      );

      // Prepare second set of items and update the box
      final items2 = [
        Item(text: 'initial', lastModifiedBy: 'user'),
        Item(text: 'added', lastModifiedBy: 'user'),
      ];
      testBox.valuesList = items2;

      // Simulate a BoxEvent to trigger the watch() listener
      testBox.simulateBoxEvent(BoxEvent('added_key', items2[1], false));

      // Wait for the second emission with a shorter timeout
      final receivedItems = await secondEmission.future.timeout(
        const Duration(seconds: 1),
        onTimeout:
            () =>
                throw TimeoutException(
                  'No second emission received within timeout',
                ),
      );

      // Verify received items match expected items
      expect(
        receivedItems,
        equals(items2),
        reason: 'Second emission should match updated items',
      );

      // Clean up resources
      await subscription.cancel();
      await testService.close();
    });

    test('close closes box and controller', () async {
      // Arrange

      // Act
      await storageService.close();

      // Assert
      verify(mockBox.close()).called(1);

      // Verify stream is closed by trying to add to it (should throw)
      expect(() => storageService.watchItems(), throwsStateError);
    });

    test('create handles lock failures with retry mechanism', () async {
      // Create a new mock HiveBackend specifically for this test to
      // avoid interference from the setUp method
      final retryMockHiveBackend = MockHiveBackend<Item>();

      // Setup adapter registration to avoid null errors
      when(retryMockHiveBackend.isAdapterRegistered(0)).thenReturn(false);

      // Arrange - First call fails with lock issue, second succeeds
      int callCount = 0;
      when(retryMockHiveBackend.openBox('items')).thenAnswer((_) async {
        if (callCount++ == 0) {
          // First call throws an exception
          throw const FileSystemException('lock failed');
        } else {
          // Subsequent calls return the mock box
          return mockBox;
        }
      });

      // Act - The HiveStorageService.create factory now handles initialization
      final service = await HiveStorageService.create(
        hiveBackend: retryMockHiveBackend,
      );

      // Assert - Only 2 calls to openBox on THIS mock (separate from setUp mock)
      verify(retryMockHiveBackend.openBox('items')).called(2);
      verify(retryMockHiveBackend.closeBoxes()).called(1);
      expect(service, isA<HiveStorageService>());
    });
  });
}
