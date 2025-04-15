import 'package:flutter_riverpod/flutter_riverpod.dart';
// Provider-Importe für den Test-Container
import 'package:solid_task/core/providers/auth_providers.dart';
import 'package:solid_task/core/providers/core_providers.dart';
import 'package:solid_task/core/providers/logger_providers.dart';
import 'package:solid_task/core/providers/repository_providers.dart';
import 'package:solid_task/core/providers/storage_providers.dart';
import 'package:solid_task/core/providers/sync_manager_provider.dart';
import 'package:solid_task/core/providers/sync_providers.dart';
import 'package:solid_task/services/auth/interfaces/auth_state_change_provider.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/services/auth/interfaces/solid_provider_service.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/repository/item_repository.dart';
import 'package:solid_task/services/storage/local_storage_service.dart';
import 'package:solid_task/services/sync/sync_manager.dart';
import 'package:solid_task/services/sync/sync_service.dart';

/// Erweiterungsmethode für ProviderContainer
extension ProviderContainerExtension on ProviderContainer {
  /// Gibt alle Provider-Overrides als Liste zurück, die in Tests verwendet werden kann
  List<Override> getAllProviderOverrides() {
    return List<Override>.from(overrides);
  }
}

/// Provider container für Tests
/// 
/// Ersetzt den früheren Service Locator für Tests und ermöglicht das Überschreiben
/// von Abhängigkeiten mit Mocks oder Testdoubles.
class TestProviderContainer {
  late final ProviderContainer container;
  
  /// Erstellt einen neuen ProviderContainer für Tests und ermöglicht das Überschreiben
  /// von Abhängigkeiten durch die übergebenen Argumente.
  TestProviderContainer({
    LoggerService? loggerService,
    SolidProviderService? providerService,
    SolidAuthOperations? authOperations,
    SolidAuthState? authState,
    AuthStateChangeProvider? authStateChangeProvider,
    LocalStorageService? storageService,
    ItemRepository? itemRepository,
    SyncService? syncService,
    SyncManager? syncManager,
  }) {
    container = ProviderContainer(
      overrides: [
        // Überschreibt nur Provider, für die ein Override-Wert übergeben wurde
        if (loggerService != null)
          loggerServiceProvider.overrideWithValue(loggerService),
          
        if (providerService != null)
          solidProviderServiceProvider.overrideWithValue(providerService),
          
        if (authOperations != null)
          solidAuthOperationsProvider.overrideWithValue(authOperations),
          
        if (authState != null)
          solidAuthStateProvider.overrideWithValue(authState),
          
        if (authStateChangeProvider != null)
          _testAuthStateChangeProvider.overrideWithValue(authStateChangeProvider),
          
        if (storageService != null)
          localStorageServiceProvider.overrideWith((_) => Future.value(storageService)),
          
        if (itemRepository != null)
          baseItemRepositoryProvider.overrideWithValue(itemRepository),
          
        if (syncService != null)
          syncServiceProvider.overrideWithValue(syncService),
          
        if (syncManager != null)
          syncManagerProvider.overrideWith((_) => Future.value(syncManager)),
      ],
    );
  }

  /// Gibt die erstellte Provider-Container-Instanz zurück
  ProviderContainer getContainer() => container;
  
  /// Räumt die Provider-Container-Ressourcen auf
  void dispose() {
    container.dispose();
  }
}

// Temporäre Hilfsprovider für Tests
final _testAuthStateChangeProvider = Provider<AuthStateChangeProvider>((ref) {
  throw UnimplementedError('Dieser Provider sollte in Tests überschrieben werden');
});