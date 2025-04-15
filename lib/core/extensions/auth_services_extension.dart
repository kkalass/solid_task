import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:solid_task/core/service_locator.dart';
import 'package:solid_task/core/service_locator_builder.dart';
import 'package:solid_task/services/auth/implementations/solid_auth_service_impl.dart';
import 'package:solid_task/services/auth/implementations/solid_provider_service_impl.dart';
import 'package:solid_task/services/auth/interfaces/auth_state_change_provider.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/services/auth/interfaces/solid_provider_service.dart';
import 'package:solid_task/services/auth/jwt_decoder_wrapper.dart';
import 'package:solid_task/services/auth/solid_auth_wrapper.dart';
import 'package:solid_task/services/logger_service.dart';

/// Extension for ServiceLocatorBuilder to handle Auth services
extension AuthServiceLocatorBuilderExtension on ServiceLocatorBuilder {
  // Configuration storage
  static final Map<ServiceLocatorBuilder, _AuthConfig> _configs = {};

  /// Sets the provider service implementation
  ServiceLocatorBuilder withProviderService(
    SolidProviderService providerService,
  ) {
    _configs[this]!._providerService = providerService;
    return this;
  }

  /// Sets the SolidAuth implementation
  ServiceLocatorBuilder withSolidAuth(SolidAuth solidAuth) {
    _configs[this]!._solidAuth = solidAuth;
    return this;
  }

  /// Sets all auth-related services at once (convenience method)
  ServiceLocatorBuilder withAuthServices({
    SolidAuthState? authState,
    AuthStateChangeProvider? authStateChangeProvider,
    SolidAuthOperations? authOperations,
  }) {
    _configs[this]!._authState = authState;
    _configs[this]!._authStateChangeProvider = authStateChangeProvider;
    _configs[this]!._authOperations = authOperations;
    return this;
  }

  /// Register Storage services during the build phase
  Future<void> registerAuthServices() async {
    assert(
      _configs[this] == null,
      'Auth services have already been registered for this builder instance.',
    );
    _configs[this] = _AuthConfig();
    registerBuildHook(() async {
      final config = _configs[this]!;

      // Provider service with configurable implementation
      sl.registerLazySingleton<SolidProviderService>(
        () =>
            config._providerService ??
            SolidProviderServiceImpl(
              logger: sl<LoggerService>().createLogger("SolidProviderService"),
            ),
      );

      // SolidAuth wrapper with configurable implementation
      sl.registerLazySingleton<SolidAuth>(
        () => config._solidAuth ?? SolidAuth(),
      );

      // Auth service - use async registration since creation is asynchronous
      // Register all interfaces from the same implementation if they're not explicitly provided
      if (config._authOperations == null ||
          config._authState == null ||
          config._authStateChangeProvider == null) {
        sl.registerSingletonAsync<SolidAuthServiceImpl>(() async {
          // Create the standard auth service
          return await SolidAuthServiceImpl.create(
            loggerService: sl<LoggerService>(),
            client: sl<http.Client>(),
            providerService: sl<SolidProviderService>(),
            secureStorage: sl<FlutterSecureStorage>(),
            solidAuth: sl<SolidAuth>(),
            jwtDecoder: sl<JwtDecoderWrapper>(),
          );
        });

        await sl.isReady<SolidAuthServiceImpl>();

        // Register interfaces from the same implementation
        if (config._authOperations == null) {
          sl.registerLazySingleton<SolidAuthOperations>(
            () => sl<SolidAuthServiceImpl>(),
          );
        }

        if (config._authState == null) {
          sl.registerLazySingleton<SolidAuthState>(
            () => sl<SolidAuthServiceImpl>(),
          );
        }

        if (config._authStateChangeProvider == null) {
          sl.registerLazySingleton<AuthStateChangeProvider>(
            () => sl<SolidAuthServiceImpl>(),
          );
        }
      }

      // Register custom implementations if provided
      final authOperations = config._authOperations;
      if (authOperations != null) {
        sl.registerLazySingleton<SolidAuthOperations>(() => authOperations);
      }

      final authState = config._authState;
      if (authState != null) {
        sl.registerLazySingleton<SolidAuthState>(() => authState);
      }

      final authStateChangeProvider = config._authStateChangeProvider;
      if (authStateChangeProvider != null) {
        sl.registerLazySingleton<AuthStateChangeProvider>(
          () => authStateChangeProvider,
        );
      }
      // Clean up after registration
      _configs.remove(this);
    });
  }
}

/// Private class to hold service configurations
class _AuthConfig {
  SolidProviderService? _providerService;
  SolidAuth? _solidAuth;
  SolidAuthState? _authState;
  AuthStateChangeProvider? _authStateChangeProvider;
  SolidAuthOperations? _authOperations;

  _AuthConfig();
}
