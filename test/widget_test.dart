// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:rxdart/rxdart.dart';
import 'package:solid_task/core/service_locator.dart';
import 'package:solid_task/main.dart' as app;
import 'package:solid_task/models/item.dart';
import 'package:solid_task/screens/items_screen.dart';
import 'package:solid_task/services/auth/interfaces/auth_state_change_provider.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/sync/sync_service.dart';

import 'mocks/mock_temp_dir_path_provider.dart';

@GenerateMocks([
  SolidAuthState,
  SolidAuthOperations,
  AuthStateChangeProvider,
  ItemRepository,
  SyncService,
  LoggerService,
  ContextLogger,
  http.Client,
])
import 'widget_test.mocks.dart';

void main() {
  late MockSolidAuthState mockSolidAuthState;
  late MockSolidAuthOperations mockSolidAuthOperations;
  late MockAuthStateChangeProvider mockAuthStateChangeProvider;
  late MockItemRepository mockItemRepository;
  late MockSyncService mockSyncService;
  late MockLoggerService mockLoggerService;
  late MockContextLogger mockContextLogger;
  late MockTempDirPathProvider mockPathProvider;
  late MockClient mockHttpClient;
  late Widget capturedWidget;

  String? capturedError;

  // BehaviorSubject to simulate the stream of items - really important
  // to use BehaviorSubject instead of StreamController, because the real
  // storage uses BehaviorSubject as well since it replays its most current value
  late BehaviorSubject<List<Item>> behaviorSubject;

  setUp(() async {
    // Set up mock path provider for isolated test storage
    mockPathProvider = MockTempDirPathProvider(prefix: 'widget_test_');
    PathProviderPlatform.instance = mockPathProvider;

    // Reset captured error
    capturedError = null;

    // Create mock services
    mockSolidAuthState = MockSolidAuthState();
    mockSolidAuthOperations = MockSolidAuthOperations();
    mockAuthStateChangeProvider = MockAuthStateChangeProvider();
    mockItemRepository = MockItemRepository();
    mockSyncService = MockSyncService();
    mockLoggerService = MockLoggerService();
    mockContextLogger = MockContextLogger();
    mockHttpClient = MockClient();

    behaviorSubject = BehaviorSubject<List<Item>>.seeded([]);

    // Set up default behaviors
    when(mockSolidAuthState.isAuthenticated).thenReturn(false);
    when(mockSolidAuthState.currentUser?.webId).thenReturn(null);
    // Add stub for authStateChanges
    when(
      mockAuthStateChangeProvider.authStateChanges,
    ).thenAnswer((_) => Stream<bool>.value(false));
    when(
      mockItemRepository.watchActiveItems(),
    ).thenAnswer((_) => behaviorSubject.stream);
    when(
      mockSyncService.fullSync(),
    ).thenAnswer((_) async => SyncResult(success: true));

    // Capture error logs for debugging
    when(mockLoggerService.error(any, any, any)).thenAnswer((invocation) {
      capturedError =
          "${invocation.positionalArguments[0]} - ${invocation.positionalArguments[1]}";
    });

    // Critical stub: setup the createLogger method that's called during service locator initialization
    when(mockLoggerService.createLogger(any)).thenReturn(mockContextLogger);

    // Mock service locator initialization to use mocks
    await initServiceLocator(
      config: ServiceLocatorConfig(
        httpClient: mockHttpClient,
        loggerService: mockLoggerService,
        authState: mockSolidAuthState,
        authOperations: mockSolidAuthOperations,
        authStateChangeProvider: mockAuthStateChangeProvider,
        itemRepositoryFactory: (_, __) => mockItemRepository,
        syncServiceFactory: (_, __, ___, ____, _____) => mockSyncService,
      ),
    );
  });

  tearDown(() async {
    behaviorSubject.close();

    // Reset service locator after each test
    sl.reset();

    // Clean up temporary directory
    await mockPathProvider.cleanup();
  });

  testWidgets('App should render ItemsScreen with empty state', (
    WidgetTester tester,
  ) async {
    // Set system locale to English for the test using the non-deprecated approach
    tester.platformDispatcher.localesTestValue = [const Locale('en')];
    addTearDown(() {
      tester.platformDispatcher.clearLocalesTestValue();
    });

    // Call main with a mock runApp that captures the widget
    await app.main(
      initServiceLocator:
          () async {}, // Skip initialization as it's done in setUp
      logger: mockLoggerService,
      runApp: (widget) => capturedWidget = widget,
    );

    // Debugging: Check if we got an ErrorApp instead of MyApp
    if (capturedWidget is app.ErrorApp) {
      final errorApp = capturedWidget as app.ErrorApp;
      fail(
        'Error screen shown instead of main app. Error: ${errorApp.error}\nCaptured logger error: $capturedError',
      );
    }

    // Use the widget returned by main directly - it already has localization
    await tester.pumpWidget(capturedWidget);
    await tester.pumpAndSettle();

    // Verify basic structure
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(ItemsScreen), findsOneWidget);

    // Check for AppBar with the expected English title "My Tasks"
    final appBarFinder = find.byType(AppBar);
    expect(appBarFinder, findsOneWidget);

    // Look for the "My Tasks" text that should be present with the English locale
    expect(
      find.text('My Tasks'),
      findsOneWidget,
      reason:
          'The localized AppBar title "My Tasks" should be visible with English locale',
    );

    // Check for task input field which should be present even with no tasks
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Adding a task should update the list', (
    WidgetTester tester,
  ) async {
    // Set system locale to English for the test
    tester.platformDispatcher.localesTestValue = [const Locale('en')];
    addTearDown(() {
      tester.platformDispatcher.clearLocalesTestValue();
    });

    // Create a simple list of items that we can modify directly
    final testItems = <Item>[];

    // Configure mocks with behavior matching production implementation
    when(mockItemRepository.createItem(any, any)).thenAnswer((invocation) {
      final itemText = invocation.positionalArguments[0] as String;
      final newItem = Item(text: itemText, lastModifiedBy: 'local');
      testItems.add(newItem);
      // Emit updated items to the behavior subject
      behaviorSubject.add(List<Item>.from(testItems));
      return Future.value(newItem);
    });

    // Launch the app
    await app.main(
      initServiceLocator: () async {},
      logger: mockLoggerService,
      runApp: (widget) => capturedWidget = widget,
    );

    // Build our app and trigger a frame
    await tester.pumpWidget(capturedWidget);
    await tester.pump();

    // Verify we start with no tasks (behavior subject was seeded with empty list in setUp)
    expect(find.text('No tasks yet'), findsOneWidget);

    // Enter text in the TextField
    await tester.enterText(find.byType(TextField), 'Test Task');
    await tester.pump();

    // Simulate pressing Enter/Done
    await tester.testTextInput.receiveAction(TextInputAction.done);

    // Wait for UI to process the changes
    await tester.pump(); // Process the action
    await tester.pump(); // Process the stream update

    // Verify repository was called correctly
    verify(mockItemRepository.createItem('Test Task', any)).called(1);

    // Verify task was added to the UI
    expect(find.text('Test Task'), findsOneWidget);
  });

  testWidgets('Should show login page when cloud icon is tapped', (
    WidgetTester tester,
  ) async {
    // Set system locale to English for the test using the non-deprecated approach
    tester.platformDispatcher.localesTestValue = [const Locale('en')];
    addTearDown(() {
      tester.platformDispatcher.clearLocalesTestValue();
    });

    // Call main with a mock runApp that captures the widget
    await app.main(
      initServiceLocator:
          () async {}, // Skip initialization as it's done in setUp
      logger: mockLoggerService,
      runApp: (widget) => capturedWidget = widget,
    );

    // Build our app and trigger a frame
    await tester.pumpWidget(capturedWidget);
    await tester.pumpAndSettle();

    // Find and tap the cloud upload icon
    await tester.tap(find.byIcon(Icons.cloud_upload));
    await tester.pumpAndSettle();

    // Verify the login page is displayed
    expect(
      find.text('Connect to Solid Pod'),
      findsOneWidget,
      reason: 'The localized login page title should be visible',
    );
  });

  testWidgets('Should show German localized text when locale is set to German', (
    WidgetTester tester,
  ) async {
    // Set system locale to German for the test using the non-deprecated approach
    tester.platformDispatcher.localesTestValue = [const Locale('de')];
    addTearDown(() {
      tester.platformDispatcher.clearLocalesTestValue();
    });

    // Call main with a mock runApp that captures the widget
    await app.main(
      initServiceLocator:
          () async {}, // Skip initialization as it's done in setUp
      logger: mockLoggerService,
      runApp: (widget) => capturedWidget = widget,
    );

    // Build our app and trigger a frame
    await tester.pumpWidget(capturedWidget);
    await tester.pumpAndSettle();

    // Verify that the German title "Meine Aufgaben" is displayed in the AppBar
    expect(
      find.text('Meine Aufgaben'),
      findsOneWidget,
      reason:
          'The German localized AppBar title "Meine Aufgaben" should be visible',
    );

    // Verify that the text input placeholder is also in German
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    final InputDecoration decoration =
        ((textField.evaluate().first.widget as TextField).decoration
            as InputDecoration);
    expect(decoration.hintText, 'Neue Aufgabe hinzufügen...');
  });
}
