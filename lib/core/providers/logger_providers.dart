import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solid_task/services/logger_service.dart';

/// Provider for logging service
final loggerServiceProvider = Provider<LoggerService>((ref) {
  return LoggerService();
});

/// Creates a scoped logger with a specific context
final scopedLoggerProvider = Provider.family<ContextLogger, String>((ref, context) {
  return ref.watch(loggerServiceProvider).createLogger(context);
});