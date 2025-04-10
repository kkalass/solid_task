/// Represents an authentication token for SOLID authentication
class AuthToken {
  /// The raw access token string
  final String accessToken;

  /// The decoded token data as a map
  final Map<String, dynamic>? decodedData;

  /// The expiration timestamp of the token
  final DateTime? expiresAt;

  /// Creates a new authentication token
  const AuthToken({
    required this.accessToken,
    this.decodedData,
    this.expiresAt,
  });

  /// Checks if the token is still valid (not expired)
  bool get isValid {
    if (expiresAt == null) return true; // No expiry date means always valid
    return DateTime.now().isBefore(expiresAt!);
  }
}
