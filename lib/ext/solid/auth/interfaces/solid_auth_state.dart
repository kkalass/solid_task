import 'package:flutter/foundation.dart';
import 'package:solid_task/ext/solid/auth/models/user_identity.dart';

/// Interface representing the state of a SOLID authentication session
/// Combines both state access and change notifications for better consistency
abstract class SolidAuthState {
  /// Whether the user is currently authenticated
  bool get isAuthenticated;

  /// The current user's identity, if authenticated
  UserIdentity? get currentUser;

  /// Stream of authentication state changes
  /// Emits true when the user is authenticated, false otherwise
  ValueListenable<bool> get authStateChanges;
}
