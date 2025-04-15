import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:solid_task/core/providers/logger_providers.dart';
import 'package:solid_task/services/auth/implementations/solid_provider_service_impl.dart';
import 'package:solid_task/services/auth/interfaces/solid_provider_service.dart';
import 'package:solid_task/services/auth/jwt_decoder_wrapper.dart';
import 'package:solid_task/services/auth/solid_auth_wrapper.dart';

/// Provider for HTTP client
final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

/// Provider for secure storage
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// Provider for JWT decoder
final jwtDecoderProvider = Provider<JwtDecoderWrapper>((ref) {
  return JwtDecoderWrapper();
});

/// Provider for Solid Auth
final solidAuthProvider = Provider<SolidAuth>((ref) {
  return SolidAuth();
});

/// Provider for Solid Provider Service
final solidProviderServiceProvider = Provider<SolidProviderService>((ref) {
  return SolidProviderServiceImpl(
    logger: ref.watch(scopedLoggerProvider('SolidProviderService')),
  );
});