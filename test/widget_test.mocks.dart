// Mocks generated by Mockito 5.4.5 from annotations
// in solid_task/test/widget_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i7;
import 'dart:convert' as _i11;
import 'dart:typed_data' as _i12;

import 'package:flutter/widgets.dart' as _i9;
import 'package:http/http.dart' as _i6;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i8;
import 'package:solid_task/models/item.dart' as _i3;
import 'package:solid_task/services/auth/auth_service.dart' as _i2;
import 'package:solid_task/services/logger_service.dart' as _i5;
import 'package:solid_task/services/repository/item_repository.dart' as _i10;
import 'package:solid_task/services/sync/sync_service.dart' as _i4;

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

class _FakeAuthResult_0 extends _i1.SmartFake implements _i2.AuthResult {
  _FakeAuthResult_0(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeItem_1 extends _i1.SmartFake implements _i3.Item {
  _FakeItem_1(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeSyncResult_2 extends _i1.SmartFake implements _i4.SyncResult {
  _FakeSyncResult_2(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeContextLogger_3 extends _i1.SmartFake implements _i5.ContextLogger {
  _FakeContextLogger_3(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeResponse_4 extends _i1.SmartFake implements _i6.Response {
  _FakeResponse_4(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeStreamedResponse_5 extends _i1.SmartFake
    implements _i6.StreamedResponse {
  _FakeStreamedResponse_5(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

/// A class which mocks [AuthService].
///
/// See the documentation for Mockito's code generation for more information.
class MockAuthService extends _i1.Mock implements _i2.AuthService {
  MockAuthService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  bool get isAuthenticated =>
      (super.noSuchMethod(
            Invocation.getter(#isAuthenticated),
            returnValue: false,
          )
          as bool);

  @override
  _i7.Future<List<Map<String, dynamic>>> loadProviders() =>
      (super.noSuchMethod(
            Invocation.method(#loadProviders, []),
            returnValue: _i7.Future<List<Map<String, dynamic>>>.value(
              <Map<String, dynamic>>[],
            ),
          )
          as _i7.Future<List<Map<String, dynamic>>>);

  @override
  _i7.Future<String> getIssuer(String? input) =>
      (super.noSuchMethod(
            Invocation.method(#getIssuer, [input]),
            returnValue: _i7.Future<String>.value(
              _i8.dummyValue<String>(
                this,
                Invocation.method(#getIssuer, [input]),
              ),
            ),
          )
          as _i7.Future<String>);

  @override
  _i7.Future<_i2.AuthResult> authenticate(
    String? issuerUri,
    _i9.BuildContext? context,
  ) =>
      (super.noSuchMethod(
            Invocation.method(#authenticate, [issuerUri, context]),
            returnValue: _i7.Future<_i2.AuthResult>.value(
              _FakeAuthResult_0(
                this,
                Invocation.method(#authenticate, [issuerUri, context]),
              ),
            ),
          )
          as _i7.Future<_i2.AuthResult>);

  @override
  _i7.Future<String?> getPodUrl(String? webId) =>
      (super.noSuchMethod(
            Invocation.method(#getPodUrl, [webId]),
            returnValue: _i7.Future<String?>.value(),
          )
          as _i7.Future<String?>);

  @override
  _i7.Future<void> logout() =>
      (super.noSuchMethod(
            Invocation.method(#logout, []),
            returnValue: _i7.Future<void>.value(),
            returnValueForMissingStub: _i7.Future<void>.value(),
          )
          as _i7.Future<void>);

  @override
  String generateDpopToken(String? url, String? method) =>
      (super.noSuchMethod(
            Invocation.method(#generateDpopToken, [url, method]),
            returnValue: _i8.dummyValue<String>(
              this,
              Invocation.method(#generateDpopToken, [url, method]),
            ),
          )
          as String);
}

/// A class which mocks [ItemRepository].
///
/// See the documentation for Mockito's code generation for more information.
class MockItemRepository extends _i1.Mock implements _i10.ItemRepository {
  MockItemRepository() {
    _i1.throwOnMissingStub(this);
  }

  @override
  List<_i3.Item> getAllItems() =>
      (super.noSuchMethod(
            Invocation.method(#getAllItems, []),
            returnValue: <_i3.Item>[],
          )
          as List<_i3.Item>);

  @override
  List<_i3.Item> getActiveItems() =>
      (super.noSuchMethod(
            Invocation.method(#getActiveItems, []),
            returnValue: <_i3.Item>[],
          )
          as List<_i3.Item>);

  @override
  _i3.Item? getItem(String? id) =>
      (super.noSuchMethod(Invocation.method(#getItem, [id])) as _i3.Item?);

  @override
  _i7.Future<_i3.Item> createItem(String? text, String? creator) =>
      (super.noSuchMethod(
            Invocation.method(#createItem, [text, creator]),
            returnValue: _i7.Future<_i3.Item>.value(
              _FakeItem_1(
                this,
                Invocation.method(#createItem, [text, creator]),
              ),
            ),
          )
          as _i7.Future<_i3.Item>);

  @override
  _i7.Future<_i3.Item> updateItem(_i3.Item? item, String? updater) =>
      (super.noSuchMethod(
            Invocation.method(#updateItem, [item, updater]),
            returnValue: _i7.Future<_i3.Item>.value(
              _FakeItem_1(
                this,
                Invocation.method(#updateItem, [item, updater]),
              ),
            ),
          )
          as _i7.Future<_i3.Item>);

  @override
  _i7.Future<void> deleteItem(String? id, String? deletedBy) =>
      (super.noSuchMethod(
            Invocation.method(#deleteItem, [id, deletedBy]),
            returnValue: _i7.Future<void>.value(),
            returnValueForMissingStub: _i7.Future<void>.value(),
          )
          as _i7.Future<void>);

  @override
  _i7.Future<void> mergeItems(List<_i3.Item>? remoteItems) =>
      (super.noSuchMethod(
            Invocation.method(#mergeItems, [remoteItems]),
            returnValue: _i7.Future<void>.value(),
            returnValueForMissingStub: _i7.Future<void>.value(),
          )
          as _i7.Future<void>);

  @override
  _i7.Stream<List<_i3.Item>> watchActiveItems() =>
      (super.noSuchMethod(
            Invocation.method(#watchActiveItems, []),
            returnValue: _i7.Stream<List<_i3.Item>>.empty(),
          )
          as _i7.Stream<List<_i3.Item>>);

  @override
  List<Map<String, dynamic>> exportItems() =>
      (super.noSuchMethod(
            Invocation.method(#exportItems, []),
            returnValue: <Map<String, dynamic>>[],
          )
          as List<Map<String, dynamic>>);

  @override
  _i7.Future<void> importItems(List<dynamic>? jsonData) =>
      (super.noSuchMethod(
            Invocation.method(#importItems, [jsonData]),
            returnValue: _i7.Future<void>.value(),
            returnValueForMissingStub: _i7.Future<void>.value(),
          )
          as _i7.Future<void>);
}

/// A class which mocks [SyncService].
///
/// See the documentation for Mockito's code generation for more information.
class MockSyncService extends _i1.Mock implements _i4.SyncService {
  MockSyncService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  bool get isConnected =>
      (super.noSuchMethod(Invocation.getter(#isConnected), returnValue: false)
          as bool);

  @override
  _i7.Future<_i4.SyncResult> syncToRemote() =>
      (super.noSuchMethod(
            Invocation.method(#syncToRemote, []),
            returnValue: _i7.Future<_i4.SyncResult>.value(
              _FakeSyncResult_2(this, Invocation.method(#syncToRemote, [])),
            ),
          )
          as _i7.Future<_i4.SyncResult>);

  @override
  _i7.Future<_i4.SyncResult> syncFromRemote() =>
      (super.noSuchMethod(
            Invocation.method(#syncFromRemote, []),
            returnValue: _i7.Future<_i4.SyncResult>.value(
              _FakeSyncResult_2(this, Invocation.method(#syncFromRemote, [])),
            ),
          )
          as _i7.Future<_i4.SyncResult>);

  @override
  _i7.Future<_i4.SyncResult> fullSync() =>
      (super.noSuchMethod(
            Invocation.method(#fullSync, []),
            returnValue: _i7.Future<_i4.SyncResult>.value(
              _FakeSyncResult_2(this, Invocation.method(#fullSync, [])),
            ),
          )
          as _i7.Future<_i4.SyncResult>);

  @override
  void startPeriodicSync(Duration? interval) => super.noSuchMethod(
    Invocation.method(#startPeriodicSync, [interval]),
    returnValueForMissingStub: null,
  );

  @override
  void stopPeriodicSync() => super.noSuchMethod(
    Invocation.method(#stopPeriodicSync, []),
    returnValueForMissingStub: null,
  );

  @override
  void dispose() => super.noSuchMethod(
    Invocation.method(#dispose, []),
    returnValueForMissingStub: null,
  );
}

/// A class which mocks [LoggerService].
///
/// See the documentation for Mockito's code generation for more information.
class MockLoggerService extends _i1.Mock implements _i5.LoggerService {
  MockLoggerService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i5.ContextLogger createLogger(String? context) =>
      (super.noSuchMethod(
            Invocation.method(#createLogger, [context]),
            returnValue: _FakeContextLogger_3(
              this,
              Invocation.method(#createLogger, [context]),
            ),
          )
          as _i5.ContextLogger);

  @override
  void configure({int? maxLogSize, int? maxLogFiles}) => super.noSuchMethod(
    Invocation.method(#configure, [], {
      #maxLogSize: maxLogSize,
      #maxLogFiles: maxLogFiles,
    }),
    returnValueForMissingStub: null,
  );

  @override
  _i7.Future<void> init() =>
      (super.noSuchMethod(
            Invocation.method(#init, []),
            returnValue: _i7.Future<void>.value(),
            returnValueForMissingStub: _i7.Future<void>.value(),
          )
          as _i7.Future<void>);

  @override
  void debug(String? message, [Object? error, StackTrace? stackTrace]) =>
      super.noSuchMethod(
        Invocation.method(#debug, [message, error, stackTrace]),
        returnValueForMissingStub: null,
      );

  @override
  void info(String? message, [Object? error, StackTrace? stackTrace]) =>
      super.noSuchMethod(
        Invocation.method(#info, [message, error, stackTrace]),
        returnValueForMissingStub: null,
      );

  @override
  void warning(String? message, [Object? error, StackTrace? stackTrace]) =>
      super.noSuchMethod(
        Invocation.method(#warning, [message, error, stackTrace]),
        returnValueForMissingStub: null,
      );

  @override
  void error(String? message, [Object? error, StackTrace? stackTrace]) =>
      super.noSuchMethod(
        Invocation.method(#error, [message, error, stackTrace]),
        returnValueForMissingStub: null,
      );

  @override
  _i7.Future<String?> getLogContents() =>
      (super.noSuchMethod(
            Invocation.method(#getLogContents, []),
            returnValue: _i7.Future<String?>.value(),
          )
          as _i7.Future<String?>);

  @override
  _i7.Future<List<String>> getAllLogContents() =>
      (super.noSuchMethod(
            Invocation.method(#getAllLogContents, []),
            returnValue: _i7.Future<List<String>>.value(<String>[]),
          )
          as _i7.Future<List<String>>);

  @override
  _i7.Future<void> dispose() =>
      (super.noSuchMethod(
            Invocation.method(#dispose, []),
            returnValue: _i7.Future<void>.value(),
            returnValueForMissingStub: _i7.Future<void>.value(),
          )
          as _i7.Future<void>);
}

/// A class which mocks [ContextLogger].
///
/// See the documentation for Mockito's code generation for more information.
class MockContextLogger extends _i1.Mock implements _i5.ContextLogger {
  MockContextLogger() {
    _i1.throwOnMissingStub(this);
  }

  @override
  void debug(String? message, [Object? error, StackTrace? stackTrace]) =>
      super.noSuchMethod(
        Invocation.method(#debug, [message, error, stackTrace]),
        returnValueForMissingStub: null,
      );

  @override
  void info(String? message, [Object? error, StackTrace? stackTrace]) =>
      super.noSuchMethod(
        Invocation.method(#info, [message, error, stackTrace]),
        returnValueForMissingStub: null,
      );

  @override
  void warning(String? message, [Object? error, StackTrace? stackTrace]) =>
      super.noSuchMethod(
        Invocation.method(#warning, [message, error, stackTrace]),
        returnValueForMissingStub: null,
      );

  @override
  void error(String? message, [Object? error, StackTrace? stackTrace]) =>
      super.noSuchMethod(
        Invocation.method(#error, [message, error, stackTrace]),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [Client].
///
/// See the documentation for Mockito's code generation for more information.
class MockClient extends _i1.Mock implements _i6.Client {
  MockClient() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i7.Future<_i6.Response> head(Uri? url, {Map<String, String>? headers}) =>
      (super.noSuchMethod(
            Invocation.method(#head, [url], {#headers: headers}),
            returnValue: _i7.Future<_i6.Response>.value(
              _FakeResponse_4(
                this,
                Invocation.method(#head, [url], {#headers: headers}),
              ),
            ),
          )
          as _i7.Future<_i6.Response>);

  @override
  _i7.Future<_i6.Response> get(Uri? url, {Map<String, String>? headers}) =>
      (super.noSuchMethod(
            Invocation.method(#get, [url], {#headers: headers}),
            returnValue: _i7.Future<_i6.Response>.value(
              _FakeResponse_4(
                this,
                Invocation.method(#get, [url], {#headers: headers}),
              ),
            ),
          )
          as _i7.Future<_i6.Response>);

  @override
  _i7.Future<_i6.Response> post(
    Uri? url, {
    Map<String, String>? headers,
    Object? body,
    _i11.Encoding? encoding,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #post,
              [url],
              {#headers: headers, #body: body, #encoding: encoding},
            ),
            returnValue: _i7.Future<_i6.Response>.value(
              _FakeResponse_4(
                this,
                Invocation.method(
                  #post,
                  [url],
                  {#headers: headers, #body: body, #encoding: encoding},
                ),
              ),
            ),
          )
          as _i7.Future<_i6.Response>);

  @override
  _i7.Future<_i6.Response> put(
    Uri? url, {
    Map<String, String>? headers,
    Object? body,
    _i11.Encoding? encoding,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #put,
              [url],
              {#headers: headers, #body: body, #encoding: encoding},
            ),
            returnValue: _i7.Future<_i6.Response>.value(
              _FakeResponse_4(
                this,
                Invocation.method(
                  #put,
                  [url],
                  {#headers: headers, #body: body, #encoding: encoding},
                ),
              ),
            ),
          )
          as _i7.Future<_i6.Response>);

  @override
  _i7.Future<_i6.Response> patch(
    Uri? url, {
    Map<String, String>? headers,
    Object? body,
    _i11.Encoding? encoding,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #patch,
              [url],
              {#headers: headers, #body: body, #encoding: encoding},
            ),
            returnValue: _i7.Future<_i6.Response>.value(
              _FakeResponse_4(
                this,
                Invocation.method(
                  #patch,
                  [url],
                  {#headers: headers, #body: body, #encoding: encoding},
                ),
              ),
            ),
          )
          as _i7.Future<_i6.Response>);

  @override
  _i7.Future<_i6.Response> delete(
    Uri? url, {
    Map<String, String>? headers,
    Object? body,
    _i11.Encoding? encoding,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #delete,
              [url],
              {#headers: headers, #body: body, #encoding: encoding},
            ),
            returnValue: _i7.Future<_i6.Response>.value(
              _FakeResponse_4(
                this,
                Invocation.method(
                  #delete,
                  [url],
                  {#headers: headers, #body: body, #encoding: encoding},
                ),
              ),
            ),
          )
          as _i7.Future<_i6.Response>);

  @override
  _i7.Future<String> read(Uri? url, {Map<String, String>? headers}) =>
      (super.noSuchMethod(
            Invocation.method(#read, [url], {#headers: headers}),
            returnValue: _i7.Future<String>.value(
              _i8.dummyValue<String>(
                this,
                Invocation.method(#read, [url], {#headers: headers}),
              ),
            ),
          )
          as _i7.Future<String>);

  @override
  _i7.Future<_i12.Uint8List> readBytes(
    Uri? url, {
    Map<String, String>? headers,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#readBytes, [url], {#headers: headers}),
            returnValue: _i7.Future<_i12.Uint8List>.value(_i12.Uint8List(0)),
          )
          as _i7.Future<_i12.Uint8List>);

  @override
  _i7.Future<_i6.StreamedResponse> send(_i6.BaseRequest? request) =>
      (super.noSuchMethod(
            Invocation.method(#send, [request]),
            returnValue: _i7.Future<_i6.StreamedResponse>.value(
              _FakeStreamedResponse_5(
                this,
                Invocation.method(#send, [request]),
              ),
            ),
          )
          as _i7.Future<_i6.StreamedResponse>);

  @override
  void close() => super.noSuchMethod(
    Invocation.method(#close, []),
    returnValueForMissingStub: null,
  );
}
