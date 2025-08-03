import 'package:flutter/foundation.dart';
import 'package:solid_task/ext/solid/auth/interfaces/auth_state_change_provider.dart';

class MockAuthStateChangeProvider implements AuthStateChangeProvider {
  final _notifier = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get authStateChanges => _notifier;

  void emitAuthStateChange(bool isAuthenticated) {
    _notifier.value = isAuthenticated;
  }

  void dispose() {
    _notifier.dispose();
  }
}
