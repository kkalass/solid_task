import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solid_task/bootstrap/service_locator_builder.dart';
import 'package:solid_task/services/client_id_service.dart';

/// Extension for ServiceLocatorBuilder to handle Client ID services
extension ClientIdServiceLocatorBuilderExtension on ServiceLocatorBuilder {
  // Configuration storage
  static final Map<ServiceLocatorBuilder, _ClientIdConfig> _configs = {};

  /// Sets the client ID service implementation
  ServiceLocatorBuilder withClientIdServiceFactory(
    ClientIdService Function(GetIt) factory,
  ) {
    _configs[this]!._clientIdServiceFactory = factory;
    return this;
  }

  /// Register Client ID services during the build phase
  Future<void> registerClientIdServices(GetIt sl) async {
    assert(
      _configs[this] == null,
      'Client ID services have already been registered for this builder instance.',
    );
    _configs[this] = _ClientIdConfig();
    registerBuildHook(() async {
      final config = _configs[this]!;

      // Register client ID service
      sl.registerLazySingleton<ClientIdService>(() {
        final factory = config._clientIdServiceFactory;
        return factory == null
            ? DefaultClientIdService(secureStorage: sl<FlutterSecureStorage>())
            : factory(sl);
      });

      // Clean up after registration
      _configs.remove(this);
    });
  }
}

/// Private class to hold service configurations
class _ClientIdConfig {
  ClientIdService Function(GetIt)? _clientIdServiceFactory;

  _ClientIdConfig();
}
