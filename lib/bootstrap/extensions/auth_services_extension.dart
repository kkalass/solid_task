import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:solid_task/bootstrap/service_locator_builder.dart';
import 'package:solid_task/ext/solid/auth/interfaces/auth_state_change_provider.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_provider_service.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/jwt_decoder_wrapper.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/solid_authentication_backend.dart';
import 'package:solid_task/ext/solid_flutter/auth/solid_auth_service_impl.dart';
import 'package:solid_task/ext/solid_flutter/auth/solid_provider_service_impl.dart';
import 'package:solid_task/services/auth/solid_auth_wrapper_impl.dart';

/// Extension for ServiceLocatorBuilder to handle Auth services
extension AuthServiceLocatorBuilderExtension on ServiceLocatorBuilder {
  // Configuration storage
  static final Map<ServiceLocatorBuilder, _AuthConfig> _configs = {};

  /// Sets the provider service implementation
  ServiceLocatorBuilder withProviderServiceFactory(
    SolidProviderService Function(GetIt) factory,
  ) {
    _configs[this]!._providerServiceFactory = factory;
    return this;
  }

  /// Sets the SolidAuth implementation
  ServiceLocatorBuilder withSolidAuthFactory(
    SolidAuthenticationBackend Function(GetIt) factory,
  ) {
    _configs[this]!._solidAuthFactory = factory;
    return this;
  }

  /// Sets all auth-related services at once (convenience method)
  ServiceLocatorBuilder withSolidAuthStateFactory(
    SolidAuthState Function(GetIt)? factory,
  ) {
    _configs[this]!._authStateFactory = factory;
    return this;
  }

  ServiceLocatorBuilder withAuthStateChangeProviderFactory(
    AuthStateChangeProvider Function(GetIt)? factory,
  ) {
    _configs[this]!._authStateChangeProviderFactory = factory;
    return this;
  }

  ServiceLocatorBuilder withSolidAuthOperationsFactory(
    SolidAuthOperations Function(GetIt)? factory,
  ) {
    _configs[this]!._authOperationsFactory = factory;
    return this;
  }

  /// Register Storage services during the build phase
  Future<void> registerAuthServices(GetIt sl) async {
    assert(
      _configs[this] == null,
      'Auth services have already been registered for this builder instance.',
    );
    _configs[this] = _AuthConfig();
    registerBuildHook(() async {
      final config = _configs[this]!;

      // Provider service with configurable implementation
      sl.registerLazySingleton<SolidProviderService>(() {
        var providerServiceFactory = config._providerServiceFactory;
        return providerServiceFactory == null
            ? SolidProviderServiceImpl()
            : providerServiceFactory(sl);
      });

      // SolidAuth wrapper with configurable implementation
      sl.registerLazySingleton<SolidAuthenticationBackend>(() {
        final factory = config._solidAuthFactory;
        return factory == null ? SolidAuthWrapperImpl() : factory(sl);
      });

      // Auth service - use async registration since creation is asynchronous
      // Register all interfaces from the same implementation if they're not explicitly provided
      if (config._authOperationsFactory == null ||
          config._authStateFactory == null ||
          config._authStateChangeProviderFactory == null) {
        sl.registerSingletonAsync<SolidAuthServiceImpl>(() async {
          // Create the standard auth service
          return await SolidAuthServiceImpl.create(
            client: sl<http.Client>(),
            providerService: sl<SolidProviderService>(),
            secureStorage: sl<FlutterSecureStorage>(),
            solidAuth: sl<SolidAuthenticationBackend>(),
            jwtDecoder: sl<JwtDecoderWrapper>(),
          );
        });

        await sl.isReady<SolidAuthServiceImpl>();

        // Register interfaces from the same implementation
        if (config._authOperationsFactory == null) {
          sl.registerLazySingleton<SolidAuthOperations>(
            () => sl<SolidAuthServiceImpl>(),
          );
        }

        if (config._authStateFactory == null) {
          sl.registerLazySingleton<SolidAuthState>(
            () => sl<SolidAuthServiceImpl>(),
          );
        }

        if (config._authStateChangeProviderFactory == null) {
          sl.registerLazySingleton<AuthStateChangeProvider>(
            () => sl<SolidAuthServiceImpl>(),
          );
        }
      }

      // Register custom implementations if provided
      final authOperations = config._authOperationsFactory;
      if (authOperations != null) {
        sl.registerLazySingleton<SolidAuthOperations>(() => authOperations(sl));
      }

      final authState = config._authStateFactory;
      if (authState != null) {
        sl.registerLazySingleton<SolidAuthState>(() {
          return authState(sl);
        });
      }

      final authStateChangeProvider = config._authStateChangeProviderFactory;
      if (authStateChangeProvider != null) {
        sl.registerLazySingleton<AuthStateChangeProvider>(
          () => authStateChangeProvider(sl),
        );
      }
      // Clean up after registration
      _configs.remove(this);
    });
  }
}

/// Private class to hold service configurations
class _AuthConfig {
  SolidProviderService Function(GetIt)? _providerServiceFactory;
  SolidAuthenticationBackend Function(GetIt)? _solidAuthFactory;
  SolidAuthState Function(GetIt)? _authStateFactory;
  AuthStateChangeProvider Function(GetIt)? _authStateChangeProviderFactory;
  SolidAuthOperations Function(GetIt)? _authOperationsFactory;

  _AuthConfig();
}
