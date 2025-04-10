// Mocks generated by Mockito 5.4.5 from annotations
// in solid_task/test/services/solid/solid_profile_parser_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;

import 'package:mockito/mockito.dart' as _i1;
import 'package:solid_task/services/logger_service.dart' as _i2;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: must_be_immutable
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeContextLogger_0 extends _i1.SmartFake implements _i2.ContextLogger {
  _FakeContextLogger_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

/// A class which mocks [ContextLogger].
///
/// See the documentation for Mockito's code generation for more information.
class MockContextLogger extends _i1.Mock implements _i2.ContextLogger {
  MockContextLogger() {
    _i1.throwOnMissingStub(this);
  }

  @override
  void debug(
    String? message, [
    Object? error,
    StackTrace? stackTrace,
  ]) =>
      super.noSuchMethod(
        Invocation.method(
          #debug,
          [
            message,
            error,
            stackTrace,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void info(
    String? message, [
    Object? error,
    StackTrace? stackTrace,
  ]) =>
      super.noSuchMethod(
        Invocation.method(
          #info,
          [
            message,
            error,
            stackTrace,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void warning(
    String? message, [
    Object? error,
    StackTrace? stackTrace,
  ]) =>
      super.noSuchMethod(
        Invocation.method(
          #warning,
          [
            message,
            error,
            stackTrace,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void error(
    String? message, [
    Object? error,
    StackTrace? stackTrace,
  ]) =>
      super.noSuchMethod(
        Invocation.method(
          #error,
          [
            message,
            error,
            stackTrace,
          ],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [LoggerService].
///
/// See the documentation for Mockito's code generation for more information.
class MockLoggerService extends _i1.Mock implements _i2.LoggerService {
  MockLoggerService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i2.ContextLogger createLogger(String? context) => (super.noSuchMethod(
        Invocation.method(
          #createLogger,
          [context],
        ),
        returnValue: _FakeContextLogger_0(
          this,
          Invocation.method(
            #createLogger,
            [context],
          ),
        ),
      ) as _i2.ContextLogger);

  @override
  void configure({
    int? maxLogSize,
    int? maxLogFiles,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #configure,
          [],
          {
            #maxLogSize: maxLogSize,
            #maxLogFiles: maxLogFiles,
          },
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i3.Future<void> init() => (super.noSuchMethod(
        Invocation.method(
          #init,
          [],
        ),
        returnValue: _i3.Future<void>.value(),
        returnValueForMissingStub: _i3.Future<void>.value(),
      ) as _i3.Future<void>);

  @override
  void debug(
    String? message, [
    Object? error,
    StackTrace? stackTrace,
  ]) =>
      super.noSuchMethod(
        Invocation.method(
          #debug,
          [
            message,
            error,
            stackTrace,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void info(
    String? message, [
    Object? error,
    StackTrace? stackTrace,
  ]) =>
      super.noSuchMethod(
        Invocation.method(
          #info,
          [
            message,
            error,
            stackTrace,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void warning(
    String? message, [
    Object? error,
    StackTrace? stackTrace,
  ]) =>
      super.noSuchMethod(
        Invocation.method(
          #warning,
          [
            message,
            error,
            stackTrace,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void error(
    String? message, [
    Object? error,
    StackTrace? stackTrace,
  ]) =>
      super.noSuchMethod(
        Invocation.method(
          #error,
          [
            message,
            error,
            stackTrace,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i3.Future<String?> getLogContents() => (super.noSuchMethod(
        Invocation.method(
          #getLogContents,
          [],
        ),
        returnValue: _i3.Future<String?>.value(),
      ) as _i3.Future<String?>);

  @override
  _i3.Future<List<String>> getAllLogContents() => (super.noSuchMethod(
        Invocation.method(
          #getAllLogContents,
          [],
        ),
        returnValue: _i3.Future<List<String>>.value(<String>[]),
      ) as _i3.Future<List<String>>);

  @override
  _i3.Future<void> dispose() => (super.noSuchMethod(
        Invocation.method(
          #dispose,
          [],
        ),
        returnValue: _i3.Future<void>.value(),
        returnValueForMissingStub: _i3.Future<void>.value(),
      ) as _i3.Future<void>);
}
