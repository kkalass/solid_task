import 'package:mockito/annotations.dart';

import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/ext/solid/sync/sync_service.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_state.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_auth_operations.dart';

/// This file exists to generate mock classes for integration tests
///
/// The build_runner doesn't scan the integration_test directory by default,
/// so we place @GenerateMocks in the test directory and export the generated
/// mocks for use in integration tests.
@GenerateMocks([
  SolidAuthState,
  SolidAuthOperations,
  SyncService,
  ContextLogger,
])
// The import below will be created by build_runner
export 'integration_test_mocks.mocks.dart';
