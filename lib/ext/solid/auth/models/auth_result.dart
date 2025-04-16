import 'package:solid_task/ext/solid/auth/models/user_identity.dart';
import 'package:solid_task/ext/solid/auth/models/auth_token.dart';

/// Authentication result containing all necessary data from a SOLID authentication attempt
class AuthResult {
  /// The user identity if authentication was successful
  final UserIdentity? userIdentity;

  /// The authentication token if authentication was successful
  final AuthToken? token;

  /// The raw authentication data returned from the provider
  final Map<String, dynamic>? authData;

  /// An error message if authentication failed
  final String? error;

  /// Indicates if authentication was successful
  bool get isSuccess => error == null && userIdentity != null;

  /// Creates a successful authentication result
  const AuthResult({this.userIdentity, this.token, this.authData, this.error});

  /// Creates an error authentication result
  AuthResult.error(this.error)
    : userIdentity = null,
      token = null,
      authData = null;
}
