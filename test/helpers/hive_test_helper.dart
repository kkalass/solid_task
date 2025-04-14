import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:solid_task/models/item.dart';
import 'package:solid_task/models/item_operation.dart';

/// Initialisiert Hive für Tests mit einem temporären Verzeichnis
/// 
/// Verwendet TestWidgetsFlutterBinding, um sicherzustellen, dass Flutter-Widgets korrekt testen können
/// Initialisiert Hive mit einem temporären Testverzeichnis und registriert Adapters
class HiveTestHelper {
  static String? _tempDir;
  static bool _isInitialized = false;
  static final List<String> _openedBoxes = [];
  
  /// Prüft, ob Hive initialisiert wurde
  static bool get isInitialized => _isInitialized;
  
  /// Initialisiert Hive für Tests
  static Future<void> setUp() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Wenn Hive bereits initialisiert ist, zurückgeben
    if (_isInitialized) {
      return;
    }
    
    // Schließe alle geöffneten Boxen, falls vorhanden
    try {
      if (Hive.isInitialized) {
        await Hive.close();
      }
    } catch (e) {
      // Ignoriere Fehler beim Schließen, da sie in Tests vorkommen können
      print('Warnung beim Schließen vorhandener Hive-Boxen: $e');
    }
    
    // Temporäres Verzeichnis für Hive erstellen
    _tempDir = Directory.systemTemp.createTempSync('hive_test_').path;
    
    // Hive mit dem temporären Verzeichnis initialisieren
    Hive.init(_tempDir);
    _isInitialized = true;
    
    // Adapter registrieren
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ItemAdapter());
    }
    
    // Registriere ItemOperation-Adapter, falls erforderlich
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ItemOperationAdapter());
    }

    // Sicherheitsabfrage für die Operations-Box (oft ein Problem)
    await ensureOperationBoxInitialized();
  }
  
  /// Räumt temporäre Hive-Testdaten auf
  static Future<void> tearDown() async {
    if (!_isInitialized) {
      return;
    }
    
    // Zuerst alle offenen Boxen schließen
    for (final boxName in _openedBoxes) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).close();
        }
      } catch (e) {
        print('Warnung beim Schließen der Box "$boxName": $e');
      }
    }
    _openedBoxes.clear();
    
    try {
      await Hive.close();
    } catch (e) {
      // Ignoriere Fehler beim Schließen, da sie in Tests vorkommen können
      print('Warnung beim Schließen von Hive: $e');
    }
    
    if (_tempDir != null) {
      final tempDir = Directory(_tempDir!);
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (e) {
          print('Fehler beim Löschen des temporären Verzeichnisses: $e');
        }
      }
    }
    
    _isInitialized = false;
    _tempDir = null;
  }
  
  /// Erstellt und öffnet eine Test-Box
  static Future<Box<T>> getTestBox<T>(String name) async {
    await ensureInitialized();
    
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }
    
    final box = await Hive.openBox<T>(name);
    _openedBoxes.add(name);
    return box;
  }
  
  /// Hilfsmethode zum Überprüfen und ggf. Initialisieren von Hive
  static Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await setUp();
    }
  }

  /// Stellt sicher, dass die Operations-Box initialisiert ist
  static Future<void> ensureOperationBoxInitialized() async {
    await ensureInitialized();
    const operationBoxName = 'operations';
    
    if (!Hive.isBoxOpen(operationBoxName)) {
      await Hive.openBox(operationBoxName);
      _openedBoxes.add(operationBoxName);
    }
  }
}