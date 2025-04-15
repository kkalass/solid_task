import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:solid_task/core/service_locator.dart';
import 'package:solid_task/core/service_locator_builder.dart';
import 'package:solid_task/services/auth/jwt_decoder_wrapper.dart';
import 'package:solid_task/services/logger_service.dart';

/// Extension for ServiceLocatorBuilder to handle Core services
extension CoreServiceLocatorBuilderExtension on ServiceLocatorBuilder {
  // Configuration storage
  static final Map<ServiceLocatorBuilder, _CoreConfig> _configs = {};

  /// Sets the logger service implementation
  ServiceLocatorBuilder withLogger(LoggerService logger) {
    _configs[this]!._loggerService = logger;
    return this;
  }

  /// Sets the HTTP client implementation
  ServiceLocatorBuilder withHttpClient(http.Client client) {
    _configs[this]!._httpClient = client;
    return this;
  }

  /// Sets the secure storage implementation
  ServiceLocatorBuilder withSecureStorage(FlutterSecureStorage secureStorage) {
    _configs[this]!._secureStorage = secureStorage;
    return this;
  }

  /// Sets the JWT decoder implementation
  ServiceLocatorBuilder withJwtDecoder(JwtDecoderWrapper jwtDecoder) {
    _configs[this]!._jwtDecoder = jwtDecoder;
    return this;
  }

  /// Register Core services during the build phase
  Future<void> registerCoreServices() async {
    assert(
      _configs[this] == null,
      'Core services have already been registered for this builder instance.',
    );
    _configs[this] = _CoreConfig();
    registerBuildHook(() async {
      final config = _configs[this]!;

      /// Registers core services (synchronous registrations)
      // Register logger first since it's used by almost everything
      sl.registerSingleton<LoggerService>(
        config._loggerService ?? LoggerService(),
      );

      // Register HTTP client
      sl.registerLazySingleton<http.Client>(
        () => config._httpClient ?? http.Client(),
      );

      // Register secure storage
      sl.registerSingleton<FlutterSecureStorage>(
        config._secureStorage ?? const FlutterSecureStorage(),
      );

      // Register JWT decoder
      sl.registerSingleton<JwtDecoderWrapper>(
        config._jwtDecoder ?? JwtDecoderWrapper(),
      );

      // Clean up after registration
      _configs.remove(this);
    });
  }
}

/// Private class to hold service configurations
class _CoreConfig {
  LoggerService? _loggerService;
  http.Client? _httpClient;
  FlutterSecureStorage? _secureStorage;
  JwtDecoderWrapper? _jwtDecoder;

  _CoreConfig();
}
