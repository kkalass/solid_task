import 'dart:async';
import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';

class MockBox extends Mock implements Box<dynamic> {
  final List<dynamic> _values = [];
  final StreamController<BoxEvent> _watchController = StreamController<BoxEvent>.broadcast();

  @override
  Iterable<dynamic> get values {
    try {
      return super.noSuchMethod(
        Invocation.getter(#values),
        returnValue: _values,
      );
    } catch (e) {
      return _values; // Fallback if noSuchMethod throws
    }
  }

  @override
  Future<void> put(dynamic key, dynamic value) {
    return super.noSuchMethod(
      Invocation.method(#put, [key, value]),
      returnValue: Future.value(),
    );
  }

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) {
    return super.noSuchMethod(
      Invocation.method(#putAll, [entries]),
      returnValue: Future.value(),
    );
  }

  @override
  Future<void> delete(dynamic key) {
    return super.noSuchMethod(
      Invocation.method(#delete, [key]),
      returnValue: Future.value(),
    );
  }

  @override
  Stream<BoxEvent> watch({dynamic key}) {
    try {
      return super.noSuchMethod(
        Invocation.method(#watch, [], {#key: key}),
        returnValue: _watchController.stream,
      );
    } catch (e) {
      return _watchController.stream; // Fallback if noSuchMethod throws
    }
  }
  
  // Helper method to simulate box events
  void emitBoxEvent(BoxEvent event) {
    _watchController.add(event);
  }
  
  // Clean up resources
  void closeWatchStream() {
    _watchController.close();
  }
}

class MockBoxEvent implements BoxEvent {
  @override
  final dynamic key;
  
  @override
  final dynamic value;
  
  @override
  final bool deleted;

  MockBoxEvent(this.key, this.value, this.deleted);
}