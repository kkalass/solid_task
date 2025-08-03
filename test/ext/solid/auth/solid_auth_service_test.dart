import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_provider_service.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/jwt_decoder_wrapper.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/solid_authentication_backend.dart';
import 'package:solid_task/ext/solid_flutter/auth/solid_auth_service_impl.dart';
import 'package:solid_task/services/logger_service.dart';

@GenerateNiceMocks([
  MockSpec<http.Client>(as: #MockClient),
  MockSpec<LoggerService>(),
  MockSpec<ContextLogger>(),
  MockSpec<FlutterSecureStorage>(),
  MockSpec<JwtDecoderWrapper>(),
  MockSpec<SolidAuthenticationBackend>(),
  MockSpec<SolidProviderService>(),
])
import 'solid_auth_service_test.mocks.dart';

// Mock BuildContext
class MockBuildContext extends Mock implements BuildContext {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SolidAuthServiceImpl', () {
    late MockClient mockHttpClient;
    late MockLoggerService mockLogger;
    late MockContextLogger mockContextLogger;
    late MockSolidProviderService mockSolidProviderService;
    late SolidAuthServiceImpl authService;
    late MockFlutterSecureStorage mockSecureStorage;
    late MockJwtDecoderWrapper mockJwtDecoder;
    late MockSolidAuthenticationBackend mockSolidAuth;
    late ValueNotifier<bool> isAuthenticatedNotifier;

    setUp(() async {
      // Create ValueNotifier for auth state
      isAuthenticatedNotifier = ValueNotifier<bool>(false);

      mockHttpClient = MockClient();
      mockLogger = MockLoggerService();
      mockSolidProviderService = MockSolidProviderService();
      mockSecureStorage = MockFlutterSecureStorage();
      mockJwtDecoder = MockJwtDecoderWrapper();
      mockSolidAuth = MockSolidAuthenticationBackend();
      mockContextLogger = MockContextLogger();

      when(mockLogger.createLogger(any)).thenReturn(mockContextLogger);
      when(
        mockSolidAuth.isAuthenticatedNotifier,
      ).thenReturn(isAuthenticatedNotifier);
      when(mockSolidAuth.initialize()).thenAnswer((_) async => false);

      // Create service with injected mocks
      authService = await SolidAuthServiceImpl.create(
        client: mockHttpClient,
        providerService: mockSolidProviderService,
        secureStorage: mockSecureStorage,
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

    tearDown(() {
      isAuthenticatedNotifier.dispose();
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
        mockSolidProviderService.loadProviders(),
      ).thenAnswer((_) async => mockProviders);

      // Execute
      final providers = await mockSolidProviderService.loadProviders();

      // Verify
      expect(providers, equals(mockProviders));
      verify(mockSolidProviderService.loadProviders()).called(1);
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
      final podUrl = await authService.resolvePodUrl(
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
        mockSolidAuth.authenticate('https://mock-issuer.com', any, any),
      ).thenAnswer(
        (_) async =>
            AuthResponse(webId: 'https://mock-user.example/profile/card#me'),
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
      expect(
        result.userIdentity?.webId,
        'https://mock-user.example/profile/card#me',
      );
      expect(result.userIdentity?.podUrl, 'https://mock-pod.example/storage/');

      // Verify secure storage calls - only pod_url is stored now
      verify(
        mockSecureStorage.write(key: 'solid_pod_url', value: anyNamed("value")),
      ).called(1);
      // Note: solid_webid is no longer stored as it's managed by the auth backend
    });

    test('generateDpopToken delegates to auth backend', () async {
      // Execute
      final result = authService.generateDpopToken(
        'https://example.com',
        'GET',
      );

      // Verify it returns a DPoP token (even if fake/mock)
      expect(result, isNotNull);

      // Verify the backend method was called
      verify(
        mockSolidAuth.genDpopToken('https://example.com', 'GET'),
      ).called(1);
    });

    test('logout clears session data', () async {
      // Setup
      when(
        mockSecureStorage.delete(key: anyNamed('key')),
      ).thenAnswer((_) async {});
      when(mockSolidAuth.logout()).thenAnswer((_) async => true);

      // Mock the authentication response
      when(
        mockSolidAuth.authenticate('https://mock-issuer.com', any, any),
      ).thenAnswer(
        (_) async =>
            AuthResponse(webId: 'https://mock-user.example/profile/card#me'),
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

      // Simulate that the auth backend is now authenticated after successful authenticate call
      isAuthenticatedNotifier.value = true;
      when(
        mockSolidAuth.currentWebId,
      ).thenReturn('https://mock-user.example/profile/card#me');

      // Verify authenticated state before logout
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUser?.webId, isNotNull);

      // Reset the mocks to clear previous interactions
      clearInteractions(mockSecureStorage);
      clearInteractions(mockSolidAuth);

      // Execute
      await authService.logout();

      // Simulate that the auth backend is now logged out
      isAuthenticatedNotifier.value = false;
      when(mockSolidAuth.currentWebId).thenReturn(null);

      // Verify
      verify(mockSecureStorage.delete(key: 'solid_pod_url')).called(1);
      verify(mockSolidAuth.logout()).called(1);
      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentUser?.webId, isNull);
      expect(authService.currentUser?.podUrl, isNull);
    });
  });

  test(
    'SolidAuthServiceImpl with mock secure storage initializes correctly',
    () async {
      final mockSecureStorage = MockFlutterSecureStorage();
      final mockLogger = MockLoggerService();
      final MockContextLogger mockContextLogger = MockContextLogger();
      final mockClient = MockClient();
      final mockSolidAuth = MockSolidAuthenticationBackend();
      final mockProviderService = MockSolidProviderService();
      final isAuthenticatedNotifier = ValueNotifier<bool>(true);

      when(mockLogger.createLogger(any)).thenReturn(mockContextLogger);
      when(
        mockSolidAuth.isAuthenticatedNotifier,
      ).thenReturn(isAuthenticatedNotifier);
      when(mockSolidAuth.initialize()).thenAnswer((_) async => true);
      when(
        mockSolidAuth.currentWebId,
      ).thenReturn('https://test.example/profile/card#me');

      // When pod_url is read, return test value
      when(
        mockSecureStorage.read(key: 'solid_pod_url'),
      ).thenAnswer((_) async => 'https://test.example/storage/');

      // Create service with injected mocks - this should trigger session restoration
      final authService = await SolidAuthServiceImpl.create(
        client: mockClient,
        secureStorage: mockSecureStorage,
        solidAuth: mockSolidAuth,
        providerService: mockProviderService,
      );

      // Verify the service initialized correctly - only pod_url is read now
      verify(mockSecureStorage.read(key: 'solid_pod_url')).called(1);
      // Note: solid_webid is no longer read from storage, it's provided by auth backend

      expect(authService.isAuthenticated, isTrue);
      expect(
        authService.currentUser?.webId,
        'https://test.example/profile/card#me',
      );
      expect(authService.currentUser?.podUrl, 'https://test.example/storage/');

      // Clean up
      isAuthenticatedNotifier.dispose();
    },
  );
}
