import 'package:hive_flutter/hive_flutter.dart';

/// Interface for abstracting Hive operations
/// This allows for proper dependency injection and testing
abstract class HiveBackend<T> {
  /// Initializes the Hive backend
  Future<void> initFlutter([String? subDir]);

  /// Registers a type adapter
  void registerAdapter<A>(TypeAdapter<A> adapter);

  /// Checks if an adapter is registered
  bool isAdapterRegistered(int typeId);

  /// Opens a Hive box
  Future<Box<T>> openBox(String boxName);

  /// Closes all boxes
  Future<void> closeBoxes();
}

/// Default implementation of HiveBackend that uses the real Hive library
class DefaultHiveBackend<T> implements HiveBackend<T> {
  @override
  Future<void> initFlutter([String? subDir]) async {
    return Hive.initFlutter(subDir);
  }

  @override
  void registerAdapter<A>(TypeAdapter<A> adapter) {
    Hive.registerAdapter(adapter);
  }

  @override
  bool isAdapterRegistered(int typeId) {
    return Hive.isAdapterRegistered(typeId);
  }

  @override
  Future<Box<T>> openBox(String boxName) async {
    return Hive.openBox<T>(boxName);
  }

  @override
  Future<void> closeBoxes() async {
    return Hive.close();
  }
}
