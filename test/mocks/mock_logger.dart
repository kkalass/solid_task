import 'package:mockito/mockito.dart';
import 'package:solid_task/services/logger_service.dart';

class MockLogger extends Mock implements ContextLogger {
  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    super.noSuchMethod(
      Invocation.method(#debug, [message, error, stackTrace]),
    );
  }

  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    super.noSuchMethod(
      Invocation.method(#info, [message, error, stackTrace]),
    );
  }

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    super.noSuchMethod(
      Invocation.method(#warning, [message, error, stackTrace]),
    );
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    super.noSuchMethod(
      Invocation.method(#error, [message, error, stackTrace]),
    );
  }
}