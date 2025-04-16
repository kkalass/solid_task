import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:solid_task/ext/solid_flutter/auth/integration/jwt_decoder_wrapper.dart';

/// Wrapper for JwtDecoder to allow mocking in tests
///
/// This class provides an abstraction over the JWT decoding functionality,
/// making it possible to inject mock implementations for testing.
class JwtDecoderWrapperImpl implements JwtDecoderWrapper {
  /// Decodes a JWT token and returns its payload as a Map
  @override
  Map<String, dynamic> decode(String token) {
    return JwtDecoder.decode(token);
  }

  /// Checks if a JWT token is expired
  @override
  bool isTokenExpired(String token) {
    return JwtDecoder.isExpired(token);
  }

  /// Gets the expiration date from a token
  @override
  DateTime getExpirationDate(String token) {
    return JwtDecoder.getExpirationDate(token);
  }
}
