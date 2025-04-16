/// Wrapper for JwtDecoder to allow mocking in tests
///
/// This class provides an abstraction over the JWT decoding functionality,
/// making it possible to inject mock implementations for testing.
abstract interface class JwtDecoderWrapper {
  /// Decodes a JWT token and returns its payload as a Map
  Map<String, dynamic> decode(String token);

  /// Checks if a JWT token is expired
  bool isTokenExpired(String token);

  /// Gets the expiration date from a token
  DateTime getExpirationDate(String token);
}
