import 'dart:async';
import 'package:hive/hive.dart';
import 'package:solid_task/services/storage/hive_backend.dart';

/// A mock implementation of HiveBackend for testing purposes
class MockHiveBackend<T> implements HiveBackend<T> {
  final Map<String, Box<T>> _boxes = {};
  bool _isInitialized = false;
  final Map<String, Map<dynamic, T>> _boxData = {};
  final Map<int, TypeAdapter> _adapters = {};

  @override
  Box<T> box(String name) {
    if (!_boxes.containsKey(name)) {
      throw HiveError('Box $name is not open. Call openBox() first.');
    }
    return _boxes[name]!;
  }

  @override
  Future<void> close() async {
    for (final box in _boxes.values) {
      await box.close();
    }
    _boxes.clear();
  }

  @override
  Future<void> deleteBoxFromDisk(String name) async {
    _boxes.remove(name);
    _boxData.remove(name);
  }

  @override
  Future<void> initFlutter([String? path]) async {
    _isInitialized = true;
  }

  @override
  bool isBoxOpen(String name) {
    return _boxes.containsKey(name);
  }

  @override
  Future<Box<T>> openBox(String name) async {
    if (!_boxData.containsKey(name)) {
      _boxData[name] = {};
    }
    
    if (!_boxes.containsKey(name)) {
      _boxes[name] = _MockBox<T>(data: _boxData[name]!);
    }
    
    return _boxes[name]!;
  }

  @override
  Future<void> closeBoxes() async {
    for (final box in _boxes.values) {
      await box.close();
    }
    _boxes.clear();
  }

  @override
  void registerAdapter<A>(TypeAdapter<A> adapter) {
    _adapters[adapter.typeId] = adapter;
  }

  @override
  bool isAdapterRegistered(int typeId) {
    return _adapters.containsKey(typeId);
  }
}

/// A mock implementation of Box for testing purposes
class _MockBox<T> implements Box<T> {
  final Map<dynamic, T> data;
  final StreamController<BoxEvent> _watchController = 
      StreamController<BoxEvent>.broadcast();

  _MockBox({required this.data});

  @override
  Future<void> close() async {
    await _watchController.close();
  }

  @override
  Future<void> delete(key) async {
    data.remove(key);
    _notifyWatchers(key);
  }

  @override
  Future<void> deleteAll(Iterable keys) async {
    for (final key in keys) {
      data.remove(key);
      _notifyWatchers(key);
    }
  }

  @override
  Future<void> deleteAt(int index) async {
    if (index < 0 || index >= data.length) {
      throw HiveError('Index out of range');
    }
    final key = data.keys.elementAt(index);
    data.remove(key);
    _notifyWatchers(key);
  }

  @override
  T? get(key, {T? defaultValue}) {
    return data[key] ?? defaultValue;
  }

  @override
  bool containsKey(key) {
    return data.containsKey(key);
  }

  @override
  Iterable<dynamic> get keys => data.keys;

  @override
  int get length => data.length;

  @override
  String get name => 'mock_box';

  @override
  String get path => 'mock_path';

  @override
  Future<void> put(key, T value) async {
    data[key] = value;
    _notifyWatchers(key);
  }

  @override
  Future<void> putAll(Map<dynamic, T> entries) async {
    data.addAll(entries);
    for (final key in entries.keys) {
      _notifyWatchers(key);
    }
  }

  @override
  Future<void> putAt(int index, T value) async {
    if (index < 0 || index >= data.length) {
      throw HiveError('Index out of range');
    }
    final key = data.keys.elementAt(index);
    data[key] = value;
    _notifyWatchers(key);
  }

  @override
  T? getAt(int index) {
    if (index < 0 || index >= data.length) {
      throw HiveError('Index out of range');
    }
    final key = data.keys.elementAt(index);
    return data[key];
  }

  @override
  Map<dynamic, T> toMap() {
    return Map.from(data);
  }

  @override
  Iterable<T> get values => data.values;

  @override
  Stream<BoxEvent> watch({key}) {
    return _watchController.stream;
  }

  void _notifyWatchers(dynamic key) {
    if (!_watchController.isClosed) {
      _watchController.add(BoxEvent(key, data[key], false));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName} is not implemented');
  }
}