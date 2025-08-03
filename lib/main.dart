import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:solid_task/l10n/app_localizations.dart';
import 'bootstrap/service_locator.dart';
import 'screens/items_screen.dart';
import 'services/logger_service.dart';

Future<void> main({
  Future<void> Function()? initServiceLocatorOverride,
  LoggerService? logger,
  void Function(Widget) runApp = runApp,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  logger ??= LoggerService();
  await logger.init();

  try {
    // Initialize service locator with the logger
    final initFn =
        initServiceLocatorOverride ??
        (() => initServiceLocator(
          configure: (builder) => builder.withLoggerFactory((_) => logger!),
        ));

    await initFn();

    // Run the app
    runApp(const MyApp());
  } catch (e, stackTrace) {
    logger.error('Failed to start application', e, stackTrace);
    runApp(ErrorApp(error: e.toString()));
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    // Dispose all registered services when the app widget is disposed
    disposeServiceLocator();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SolidTask',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('de'), // German
      ],
      home: const ItemsScreen(),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Error',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Application Error'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Failed to initialize the application',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    main();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
