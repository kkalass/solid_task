import 'package:solid_auth/solid_auth.dart';
import 'package:solid_task/ext/solid/auth/models/auth_result.dart';

/// Interface defining operations for SOLID authentication
abstract class SolidAuthOperations<C> {
  /// Authenticates a user with a SOLID identity provider
  ///
  /// [webIdOrIssuerUri] is the WebID or the URI of the SOLID identity provider
  /// [context] is the Flutter build context needed for web authentication flows
  /// Returns an [AuthResult] containing authentication data or an error
  Future<AuthResult> authenticate(String webIdOrIssuerUri, C context);

  /// Logs the current user out
  ///
  /// Clears authentication state and terminates the session with the provider
  Future<void> logout();

  /// Resolves a user's Pod URL from their WebID
  ///
  /// [webId] is the user's WebID URI
  /// Returns the Pod URL if found, null otherwise
  Future<String?> resolvePodUrl(String webId);

  /// Generates a DPoP token for SOLID API requests
  ///
  /// [url] is the target resource URL
  /// [method] is the HTTP method to use (GET, PUT, etc.)
  /// Returns a DPoP
  DPoP generateDpopToken(String url, String method);
}
