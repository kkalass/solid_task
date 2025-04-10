import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solid_task/services/auth/jwt_decoder_wrapper.dart';
import 'package:solid_task/services/auth/solid_auth_service.dart';
import 'package:solid_task/services/auth/solid_auth_wrapper.dart';
import 'package:solid_task/services/logger_service.dart';

import 'package:solid_task/services/auth/provider_service.dart';

@GenerateNiceMocks([
  MockSpec<http.Client>(as: #MockClient),
  MockSpec<LoggerService>(),
  MockSpec<ContextLogger>(),
  MockSpec<FlutterSecureStorage>(),
  MockSpec<JwtDecoderWrapper>(),
  MockSpec<SolidAuth>(),
  MockSpec<ProviderService>(),
])
import 'solid_auth_service_test.mocks.dart';

// Mock BuildContext
class MockBuildContext extends Mock implements BuildContext {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SolidAuthService', () {
    late MockClient mockHttpClient;
    late MockLoggerService mockLogger;
    late MockContextLogger mockContextLogger;
    late MockProviderService mockProviderService;
    late SolidAuthService authService;
    late MockFlutterSecureStorage mockSecureStorage;
    late MockJwtDecoderWrapper mockJwtDecoder;
    late MockSolidAuth mockSolidAuth;

    setUp(() async {
      mockHttpClient = MockClient();
      mockLogger = MockLoggerService();
      mockProviderService = MockProviderService();
      mockSecureStorage = MockFlutterSecureStorage();
      mockJwtDecoder = MockJwtDecoderWrapper();
      mockSolidAuth = MockSolidAuth();
      mockContextLogger = MockContextLogger();

      when(mockLogger.createLogger(any)).thenReturn(mockContextLogger);

      // Create service with injected mocks
      authService = await SolidAuthService.create(
        loggerService: mockLogger,
        client: mockHttpClient,
        providerService: mockProviderService,
        secureStorage: mockSecureStorage,
        jwtDecoder: mockJwtDecoder,
        solidAuth: mockSolidAuth,
      );

      // Setup default behavior for mocks
      when(mockJwtDecoder.decode(any)).thenReturn({
        'webid': 'https://mock-user.example/profile/card#me',
        'sub': 'mock-subject',
        'exp':
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
      });
    });

    test('isAuthenticated returns false when not authenticated', () {
      // By default, no session data is set
      expect(authService.isAuthenticated, isFalse);
    });

    test('loadProviders delegates to provider service', () async {
      // Setup
      final mockProviders = [
        {'name': 'Test Provider', 'url': 'https://test.example'},
      ];
      when(
        mockProviderService.loadProviders(),
      ).thenAnswer((_) async => mockProviders);

      // Execute
      final providers = await authService.loadProviders();

      // Verify
      expect(providers, equals(mockProviders));
      verify(mockProviderService.loadProviders()).called(1);
    });

    test('getIssuer returns issuer URI', () async {
      // Mock the solid_auth.getIssuer method
      when(
        mockSolidAuth.getIssuer('https://example.com'),
      ).thenAnswer((_) async => 'https://mock-issuer.com');

      final issuer = await authService.getIssuer('https://example.com');

      expect(issuer, 'https://mock-issuer.com');
      verify(mockSolidAuth.getIssuer('https://example.com')).called(1);
    });

    test('getPodUrl extracts pod URL from profile', () async {
      // Setup with valid Turtle syntax
      const validTurtle = '''
@prefix solid: <http://www.w3.org/ns/solid/terms#>.
@prefix space: <http://www.w3.org/ns/pim/space#>.
@prefix foaf: <http://xmlns.com/foaf/0.1/>.

<https://mock-user.example/profile/card#me>
    a foaf:Person;
    foaf:name "Mock User";
    space:storage <https://mock-pod.example/storage/>;
    solid:oidcIssuer <https://mock-issuer.example>.
  ''';

      when(
        mockHttpClient.get(
          Uri.parse('https://mock-user.example/profile/card#me'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          validTurtle,
          200,
          headers: {'content-type': 'text/turtle'},
        ),
      );

      // Execute
      final podUrl = await authService.getPodUrl(
        'https://mock-user.example/profile/card#me',
      );

      // Verify
      expect(podUrl, 'https://mock-pod.example/storage/');
    });

    test('authenticate sets session data and stores it securely', () async {
      // Setup authentication mocks
      when(
        mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value')),
      ).thenAnswer((_) async {});

      when(
        mockSolidAuth.authenticate(
          Uri.parse('https://mock-issuer.com'),
          any,
          any,
        ),
      ).thenAnswer(
        (_) async => {
          'accessToken': 'mock-access-token',
          'refreshToken': 'mock-refresh-token',
          'idToken': 'mock-id-token',
          'logoutUrl': 'https://mock-issuer.com/logout',
          'rsaInfo': {
            'rsa': 'mock-rsa-key-pair',
            'pubKeyJwk': {
              'kty': 'RSA',
              'e': 'AQAB',
              'n': 'mock-n',
              'alg': 'RS256',
            },
          },
        },
      );

      // Mock profile fetching with valid Turtle
      when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response(
          '''
@prefix solid: <http://www.w3.org/ns/solid/terms#>.
@prefix space: <http://www.w3.org/ns/pim/space#>.
@prefix foaf: <http://xmlns.com/foaf/0.1/>.

<https://mock-user.example/profile/card#me>
    a foaf:Person;
    foaf:name "Mock User";
    space:storage <https://mock-pod.example/storage/>;
    solid:oidcIssuer <https://mock-issuer.example>.
    ''',
          200,
          headers: {'content-type': 'text/turtle'},
        ),
      );

      // Execute
      final result = await authService.authenticate(
        'https://mock-issuer.com',
        MockBuildContext(), // Flutter context is not used in the test
      );

      // Verify
      expect(result.isSuccess, isTrue);
      expect(result.webId, 'https://mock-user.example/profile/card#me');
      expect(result.podUrl, 'https://mock-pod.example/storage/');
      expect(result.accessToken, 'mock-access-token');

      // Verify secure storage calls
      verify(
        mockSecureStorage.write(key: 'solid_webid', value: anyNamed("value")),
      ).called(1);
      verify(
        mockSecureStorage.write(key: 'solid_pod_url', value: anyNamed("value")),
      ).called(1);
      verify(
        mockSecureStorage.write(
          key: 'solid_access_token',
          value: anyNamed("value"),
        ),
      ).called(1);
      verify(
        mockSecureStorage.write(
          key: 'solid_auth_data',
          value: anyNamed("value"),
        ),
      ).called(1);
    });

    test('generateDpopToken throws exception when not authenticated', () async {
      // Execute & Verify
      expect(
        () => authService.generateDpopToken('https://example.com', 'GET'),
        throwsA(isA<Exception>()),
      );
    });

    test('logout clears session data', () async {
      // Setup
      when(mockSecureStorage.deleteAll()).thenAnswer((_) async {});
      when(mockSolidAuth.logout(any)).thenAnswer((_) async => true);

      // Mock the authentication response
      when(
        mockSolidAuth.authenticate(
          Uri.parse('https://mock-issuer.com'),
          any,
          any,
        ),
      ).thenAnswer(
        (_) async => {
          'accessToken': 'mock-access-token',
          'refreshToken': 'mock-refresh-token',
          'idToken': 'mock-id-token',
          'logoutUrl': 'https://mock-issuer.com/logout',
          'rsaInfo': {
            'rsa': 'mock-rsa-key-pair',
            'pubKeyJwk': {
              'kty': 'RSA',
              'e': 'AQAB',
              'n': 'mock-n',
              'alg': 'RS256',
            },
          },
        },
      );

      // Mock storage write operations (needed for authenticate)
      when(
        mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value')),
      ).thenAnswer((_) async {});

      // Mock profile fetching for getPodUrl (called during authenticate)
      when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response(
          '''
@prefix solid: <http://www.w3.org/ns/solid/terms#>.
@prefix space: <http://www.w3.org/ns/pim/space#>.
@prefix foaf: <http://xmlns.com/foaf/0.1/>.

<https://mock-user.example/profile/card#me>
    a foaf:Person;
    foaf:name "Mock User";
    space:storage <https://mock-pod.example/storage/>;
    solid:oidcIssuer <https://mock-issuer.example>.
    ''',
          200,
          headers: {'content-type': 'text/turtle'},
        ),
      );

      // Set internal state of the service by calling authenticate
      final authResult = await authService.authenticate(
        'https://mock-issuer.com',
        MockBuildContext(),
      );

      // Verify authenticate succeeded
      expect(authResult.isSuccess, isTrue);

      // Verify authenticated state before logout
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentWebId, isNotNull);

      // Reset the mocks to clear previous interactions
      clearInteractions(mockSecureStorage);
      clearInteractions(mockSolidAuth);

      // Execute
      await authService.logout();

      // Verify
      verify(mockSecureStorage.deleteAll()).called(1);
      verify(mockSolidAuth.logout(any)).called(1);
      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentWebId, isNull);
      expect(authService.podUrl, isNull);
      expect(authService.accessToken, isNull);
    });
  });

  test(
    'SolidAuthService with mock secure storage initializes correctly',
    () async {
      final mockSecureStorage = MockFlutterSecureStorage();
      final mockLogger = MockLoggerService();
      final MockContextLogger mockContextLogger = MockContextLogger();
      final mockClient = MockClient();
      final mockJwtDecoder = MockJwtDecoderWrapper();
      final mockSolidAuth = MockSolidAuth();
      final mockProviderService = MockProviderService();

      when(mockLogger.createLogger(any)).thenReturn(mockContextLogger);

      // When secure storage read is called, return test values
      when(
        mockSecureStorage.read(key: 'solid_webid'),
      ).thenAnswer((_) async => 'https://test.example/profile/card#me');
      when(
        mockSecureStorage.read(key: 'solid_pod_url'),
      ).thenAnswer((_) async => 'https://test.example/storage/');
      when(
        mockSecureStorage.read(key: 'solid_access_token'),
      ).thenAnswer((_) async => 'mock-token');
      when(
        mockSecureStorage.read(key: 'solid_auth_data'),
      ).thenAnswer((_) async => '{"accessToken":"mock-token"}');

      when(mockJwtDecoder.decode('mock-token')).thenReturn({
        'webid': 'https://test.example/profile/card#me',
        'exp':
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
      });

      // Create service with injected mocks - this is supposed to trigger reading
      // from the secure storage
      final authService = await SolidAuthService.create(
        loggerService: mockLogger,
        client: mockClient,
        secureStorage: mockSecureStorage,
        jwtDecoder: mockJwtDecoder,
        solidAuth: mockSolidAuth,
        providerService: mockProviderService,
      );

      // Wait for the _tryRestoreSession to complete
      //await authService.restoreSessionForTest();

      // Verify the service initialized correctly
      verify(mockSecureStorage.read(key: 'solid_webid')).called(1);
      verify(mockSecureStorage.read(key: 'solid_pod_url')).called(1);
      verify(mockSecureStorage.read(key: 'solid_access_token')).called(1);
      verify(mockSecureStorage.read(key: 'solid_auth_data')).called(1);
      verify(mockJwtDecoder.decode('mock-token')).called(1);

      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentWebId, 'https://test.example/profile/card#me');
      expect(authService.podUrl, 'https://test.example/storage/');
    },
  );
}
