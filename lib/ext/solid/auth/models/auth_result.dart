import 'package:solid_task/ext/solid/auth/models/user_identity.dart';

/// Authentication result containing all necessary data from a SOLID authentication attempt
class AuthResult {
  /// The user identity if authentication was successful
  final UserIdentity? userIdentity;

  /// An error message if authentication failed
  final String? error;

  /// Indicates if authentication was successful
  bool get isSuccess => error == null && userIdentity != null;

  /// Creates a successful authentication result
  const AuthResult({this.userIdentity, this.error});

  /// Creates an error authentication result
  AuthResult.error(this.error) : userIdentity = null;
}
