import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:solid_task/bootstrap/service_locator_builder.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/jwt_decoder_wrapper.dart';
import 'package:solid_task/services/auth/jwt_decoder_wrapper_impl.dart';
import 'package:solid_task/services/logger_service.dart';

/// Extension for ServiceLocatorBuilder to handle Core services
extension CoreServiceLocatorBuilderExtension on ServiceLocatorBuilder {
  // Configuration storage
  static final Map<ServiceLocatorBuilder, _CoreConfig> _configs = {};

  /// Sets the logger service implementation
  ServiceLocatorBuilder withLoggerFactory(
    LoggerService Function(GetIt) logger,
  ) {
    _configs[this]!._loggerServiceFactory = logger;
    return this;
  }

  /// Sets the HTTP client implementation
  ServiceLocatorBuilder withHttpClientFactory(
    http.Client Function(GetIt) client,
  ) {
    _configs[this]!._httpClientFactory = client;
    return this;
  }

  /// Sets the secure storage implementation
  ServiceLocatorBuilder withSecureStorageFactory(
    FlutterSecureStorage Function(GetIt) secureStorage,
  ) {
    _configs[this]!._secureStorageFactory = secureStorage;
    return this;
  }

  /// Sets the JWT decoder implementation
  ServiceLocatorBuilder withJwtDecoderFactory(
    JwtDecoderWrapper Function(GetIt) jwtDecoder,
  ) {
    _configs[this]!._jwtDecoderFactory = jwtDecoder;
    return this;
  }

  /// Register Core services during the build phase
  Future<void> registerCoreServices(GetIt sl) async {
    assert(
      _configs[this] == null,
      'Core services have already been registered for this builder instance.',
    );
    _configs[this] = _CoreConfig();
    registerBuildHook(() async {
      final config = _configs[this]!;

      /// Registers core services (synchronous registrations)
      // Register logger first since it's used by almost everything
      sl.registerLazySingleton<LoggerService>(() {
        final factory = config._loggerServiceFactory;
        return factory == null ? LoggerService() : factory(sl);
      });

      // Register HTTP client
      sl.registerLazySingleton<http.Client>(() {
        final factory = config._httpClientFactory;
        return factory == null ? http.Client() : factory(sl);
      });

      // Register secure storage
      sl.registerLazySingleton<FlutterSecureStorage>(() {
        final factory = config._secureStorageFactory;
        return factory == null ? const FlutterSecureStorage() : factory(sl);
      });

      // Register JWT decoder
      sl.registerLazySingleton<JwtDecoderWrapper>(() {
        final factory = config._jwtDecoderFactory;
        return factory == null ? JwtDecoderWrapperImpl() : factory(sl);
      });

      // Clean up after registration
      _configs.remove(this);
    });
  }
}

/// Private class to hold service configurations
class _CoreConfig {
  LoggerService Function(GetIt)? _loggerServiceFactory;
  http.Client Function(GetIt)? _httpClientFactory;
  FlutterSecureStorage Function(GetIt)? _secureStorageFactory;
  JwtDecoderWrapper Function(GetIt)? _jwtDecoderFactory;

  _CoreConfig();
}
