import 'package:solid_task/ext/solid/auth/models/user_identity.dart';

/// Interface representing the state of a SOLID authentication session
abstract class SolidAuthState {
  /// Whether the user is currently authenticated
  bool get isAuthenticated;

  /// The current user's identity, if authenticated
  UserIdentity? get currentUser;
}
