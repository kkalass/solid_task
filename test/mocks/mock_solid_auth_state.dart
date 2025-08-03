import 'package:flutter/foundation.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/ext/solid/auth/models/user_identity.dart';

class MockSolidAuthState implements SolidAuthState {
  final _notifier = ValueNotifier<bool>(false);
  UserIdentity? _currentUser;

  MockSolidAuthState([UserIdentity? initialUser]) {
    if (initialUser != null) {
      _currentUser = initialUser;
      _notifier.value = true;
    }
  }

  @override
  ValueListenable<bool> get authStateChanges => _notifier;

  @override
  bool get isAuthenticated => _notifier.value;

  @override
  UserIdentity? get currentUser => _currentUser;

  void emitAuthStateChange(UserIdentity? userIdentity) {
    _currentUser = userIdentity;
    _notifier.value = userIdentity != null;
  }

  void dispose() {
    _notifier.dispose();
  }
}
