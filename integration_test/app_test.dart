import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:solid_task/core/service_locator.dart';
import 'package:solid_task/main.dart' as app;
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/sync/sync_service.dart';

import '../test/helpers/hive_test_helper.dart';
import '../test/mocks/integration_test_mocks.dart';
// Import mocks from test directory instead of generating in integration test directory
import '../test/mocks/mock_temp_dir_path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockSolidAuthState mockSolidAuthState;
  late MockSolidAuthOperations mockSolidAuthOperations;
  late MockAuthStateChangeProvider mockAuthStateChangeProvider;
  late MockSyncService mockSyncService;
  late LoggerService logger;
  late Widget appWidget;
  late MockTempDirPathProvider mockPathProvider;

  setUp(() async {
    // Create isolated storage for testing
    mockPathProvider = MockTempDirPathProvider(prefix: 'integration_test_');
    PathProviderPlatform.instance = mockPathProvider;

    // Initialize Hive for testing
    await HiveTestHelper.setUp();

    // Mock auth and sync services to avoid network dependencies
    logger = LoggerService();
    await logger.init();

    // Configure our mocks
    mockSolidAuthState = MockSolidAuthState();
    mockSolidAuthOperations = MockSolidAuthOperations();
    mockAuthStateChangeProvider = MockAuthStateChangeProvider();
    mockSyncService = MockSyncService();

    // Set up necessary stubs
    when(mockSolidAuthState.isAuthenticated).thenReturn(false);
    when(mockSolidAuthState.currentUser?.webId).thenReturn(null);
    // Add stub for authStateChanges
    when(
      mockAuthStateChangeProvider.authStateChanges,
    ).thenAnswer((_) => Stream<bool>.value(false));
    when(
      mockSyncService.fullSync(),
    ).thenAnswer((_) async => SyncResult(success: true));

    // Initialize service locator with real repository but mock auth/sync
    await initServiceLocator(
      config: ServiceLocatorConfig(
        // Use real services for storage and logging
        // But mock auth and sync to avoid external dependencies
        loggerService: logger,
        authState: mockSolidAuthState,
        authOperations: mockSolidAuthOperations,
        authStateChangeProvider: mockAuthStateChangeProvider,
        syncServiceFactory: (_, __, ___, ____, _____) => mockSyncService,
      ),
    );
  });

  tearDown(() async {
    // Clean up service locator
    sl.reset();

    // Clean up temporary test directory
    await logger.dispose();
    await mockPathProvider.cleanup();
    
    // Clean up Hive
    await HiveTestHelper.tearDown();
  });

  group('Solid Task App Integration Tests', () {
    testWidgets(
      'Application launches successfully with English locale and shows empty state',
      (WidgetTester tester) async {
        // Set the locale to English for this test
        tester.platformDispatcher.localesTestValue = [const Locale('en')];
        addTearDown(() {
          tester.platformDispatcher.clearLocalesTestValue();
        });

        // Launch the app but capture the widget instead of rendering it
        await app.main(
          initServiceLocator:
              () async {}, // Skip initialization as it's done in setUp
          logger: logger,
          runApp: (widget) => appWidget = widget,
        );

        // Now render the captured widget
        await tester.pumpWidget(appWidget);
        await tester.pumpAndSettle();

        // Verify the app bar title shows the correct localized text
        expect(
          find.text('My Tasks'),
          findsOneWidget,
          reason: 'Should show "My Tasks" in English locale',
        );

        // Check if the initial empty state is displayed
        expect(find.byIcon(Icons.task_outlined), findsOneWidget);
        expect(find.text('No tasks yet'), findsOneWidget);

        // Verify the text field placeholder is correctly localized
        final textField = find.byType(TextField);
        expect(textField, findsOneWidget);

        final InputDecoration decoration =
            ((textField.evaluate().first.widget as TextField).decoration
                as InputDecoration);
        expect(decoration.hintText, 'Add a new task...');
      },
    );

    testWidgets('Application correctly displays German localized texts', (
      WidgetTester tester,
    ) async {
      // Set the locale to German for this test
      tester.platformDispatcher.localesTestValue = [const Locale('de')];
      addTearDown(() {
        tester.platformDispatcher.clearLocalesTestValue();
      });

      // Launch the app but capture the widget instead of rendering it
      await app.main(
        initServiceLocator:
            () async {}, // Skip initialization as it's done in setUp
        logger: logger,
        runApp: (widget) => appWidget = widget,
      );

      // Now render the captured widget
      await tester.pumpWidget(appWidget);
      await tester.pumpAndSettle();

      // Verify the app bar title shows the correct localized text
      expect(
        find.text('Meine Aufgaben'),
        findsOneWidget,
        reason: 'Should show "Meine Aufgaben" in German locale',
      );

      // Check if the initial empty state is displayed with German text
      expect(find.byIcon(Icons.task_outlined), findsOneWidget);
      expect(find.text('Noch keine Aufgaben'), findsOneWidget);

      // Verify the text field placeholder is correctly localized
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      final InputDecoration decoration =
          ((textField.evaluate().first.widget as TextField).decoration
              as InputDecoration);
      expect(decoration.hintText, 'Neue Aufgabe hinzufügen...');
    });

    testWidgets('Can add a new task', (WidgetTester tester) async {
      // Set the locale to English for this test
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      addTearDown(() {
        tester.platformDispatcher.clearLocalesTestValue();
      });

      // Launch the app but capture the widget instead of rendering it
      await app.main(
        initServiceLocator:
            () async {}, // Skip initialization as it's done in setUp
        logger: logger,
        runApp: (widget) => appWidget = widget,
      );

      // Now render the captured widget
      await tester.pumpWidget(appWidget);
      await tester.pumpAndSettle();

      // Get a reference to the repository to validate data was stored
      final repository = sl<ItemRepository>();

      // Determine the initial number of items
      int initialItemCount = 0;
      await repository.watchActiveItems().first.then((items) {
        initialItemCount = items.length;
      });

      // Find the text field and enter a task
      final testTaskText =
          'Integration Test Task ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(find.byType(TextField), testTaskText);

      // Submit the task
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Validate the task was entered (UI verification)
      expect(find.text(testTaskText), findsOneWidget);

      // Validate the item was stored in the repository
      bool itemFound = false;
      await repository.watchActiveItems().first.then((items) {
        // Verify count increased and our specific item exists
        expect(items.length, initialItemCount + 1);
        itemFound = items.any((item) => item.text == testTaskText);
        expect(itemFound, true);
      });
    });

    testWidgets('Can delete a task by swiping', (WidgetTester tester) async {
      // Set the locale to English for this test
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      addTearDown(() {
        tester.platformDispatcher.clearLocalesTestValue();
      });

      // Launch the app but capture the widget instead of rendering it
      await app.main(
        initServiceLocator:
            () async {}, // Skip initialization as it's done in setUp
        logger: logger,
        runApp: (widget) => appWidget = widget,
      );

      // Now render the captured widget
      await tester.pumpWidget(appWidget);
      await tester.pumpAndSettle();

      // Get repository reference
      final repository = sl<ItemRepository>();

      // Create a specific test item with a unique name for easier finding
      final testTaskText =
          'Swipe Delete Test ${DateTime.now().millisecondsSinceEpoch}';

      // Create an item for testing
      await tester.enterText(find.byType(TextField), testTaskText);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify the task was added and visible
      expect(find.text(testTaskText), findsOneWidget);

      // Get the dismissible widget containing our specific text
      final itemCardFinder = find.ancestor(
        of: find.text(testTaskText),
        matching: find.byType(Dismissible),
      );
      expect(
        itemCardFinder,
        findsOneWidget,
        reason: 'Should find the dismissible containing our test task',
      );

      // Perform the swipe to delete
      await tester.drag(itemCardFinder, const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Verify item is removed from the UI
      expect(
        find.text(testTaskText),
        findsNothing,
        reason: 'Task should be removed from the UI after swiping',
      );

      // Verify item was marked as deleted in the repository
      bool itemDeleted = false;
      await repository.watchActiveItems().first.then((items) {
        itemDeleted = !items.any((item) => item.text == testTaskText);
      });
      expect(
        itemDeleted,
        true,
        reason: 'Item should be deleted from the repository',
      );
    });

    testWidgets('Can navigate to login screen', (WidgetTester tester) async {
      // Set the locale to English for this test
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      addTearDown(() {
        tester.platformDispatcher.clearLocalesTestValue();
      });

      // Launch the app but capture the widget instead of rendering it
      await app.main(
        initServiceLocator:
            () async {}, // Skip initialization as it's done in setUp
        logger: logger,
        runApp: (widget) => appWidget = widget,
      );

      // Now render the captured widget
      await tester.pumpWidget(appWidget);
      await tester.pumpAndSettle();

      // Find and tap the cloud icon for login
      final cloudIconFinder = find.byIcon(Icons.cloud_upload);
      expect(cloudIconFinder, findsOneWidget);

      await tester.tap(cloudIconFinder);
      await tester.pumpAndSettle();

      // Verify we're on the login screen with proper localized text
      expect(
        find.text('Connect to Solid Pod'),
        findsOneWidget,
        reason: 'Login screen title should be properly localized',
      );

      // Go back to main screen
      final backButtonFinder = find.byType(BackButton);
      if (backButtonFinder.evaluate().isNotEmpty) {
        await tester.tap(backButtonFinder);
        await tester.pumpAndSettle();

        // Verify we're back to main screen with correct localized title
        expect(find.text('My Tasks'), findsOneWidget);
      }
    });
  });
}
