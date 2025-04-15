import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solid_task/core/providers/core_providers.dart';
import 'package:solid_task/core/providers/logger_providers.dart';
import 'package:solid_task/services/auth/implementations/solid_auth_service_impl.dart';
import 'package:solid_task/services/auth/interfaces/auth_state_change_provider.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_operations.dart';
import 'package:solid_task/services/auth/interfaces/solid_auth_state.dart';

/// Provider for the Solid Auth Service implementation
/// This is implemented as a provider with AsyncValue to handle the async initialization
final solidAuthServiceImplProvider = FutureProvider<SolidAuthServiceImpl>((ref) async {
  return SolidAuthServiceImpl.create(
    loggerService: ref.watch(loggerServiceProvider),
    client: ref.watch(httpClientProvider),
    providerService: ref.watch(solidProviderServiceProvider),
    secureStorage: ref.watch(secureStorageProvider),
    solidAuth: ref.watch(solidAuthProvider),
    jwtDecoder: ref.watch(jwtDecoderProvider),
  );
});

/// Provider for auth operations interface
final solidAuthOperationsProvider = Provider<SolidAuthOperations>((ref) {
  // Use whenData to access the resolved future value
  final authService = ref.watch(solidAuthServiceImplProvider);
  
  // Return the auth service when available, or throw if there's an error
  return authService.when(
    data: (service) => service,
    loading: () => throw StateError('Auth service is still initializing'),
    error: (error, stack) => throw StateError('Failed to initialize auth service: $error'),
  );
});

/// Provider for auth state interface
final solidAuthStateProvider = Provider<SolidAuthState>((ref) {
  final authService = ref.watch(solidAuthServiceImplProvider);
  
  return authService.when(
    data: (service) => service,
    loading: () => throw StateError('Auth service is still initializing'),
    error: (error, stack) => throw StateError('Failed to initialize auth service: $error'),
  );
});

/// Provider for auth state change provider interface
final authStateChangeProvider = Provider<AuthStateChangeProvider>((ref) {
  final authService = ref.watch(solidAuthServiceImplProvider);
  
  return authService.when(
    data: (service) => service,
    loading: () => throw StateError('Auth service is still initializing'),
    error: (error, stack) => throw StateError('Failed to initialize auth service: $error'),
  );
});