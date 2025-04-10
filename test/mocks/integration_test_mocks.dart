import 'package:mockito/annotations.dart';
import 'package:solid_task/services/auth/auth_service.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/sync/sync_service.dart';

/// This file exists to generate mock classes for integration tests
///
/// The build_runner doesn't scan the integration_test directory by default,
/// so we place @GenerateMocks in the test directory and export the generated
/// mocks for use in integration tests.
@GenerateMocks([AuthService, SyncService, ContextLogger])
// The import below will be created by build_runner
export 'integration_test_mocks.mocks.dart';
