import 'package:solid_task/ext/solid/auth/models/user_identity.dart';
import 'package:solid_task/ext/solid/auth/models/auth_token.dart';

/// Interface representing the state of a SOLID authentication session
abstract class SolidAuthState {
  /// Whether the user is currently authenticated
  bool get isAuthenticated;

  /// The current user's identity, if authenticated
  UserIdentity? get currentUser;

  /// The current authentication token, if authenticated
  AuthToken? get authToken;

  /// The raw authentication data from the SOLID provider
  Map<String, dynamic>? get authData;
}
