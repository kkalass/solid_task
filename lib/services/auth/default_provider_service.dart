import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:solid_task/services/auth/provider_service.dart';
import 'package:solid_task/services/logger_service.dart';

/// Implementation of the ProviderService that loads providers from an asset file
class DefaultProviderService implements ProviderService {
  final ContextLogger _logger;
  final AssetBundle _assetBundle;

  /// Path to the providers configuration file
  final String _providersConfigPath;

  /// Creates a new DefaultProviderService with required dependencies.
  ///
  /// The [logger] is used for logging operations.
  /// The [assetBundle] is used to load assets.
  /// The [providersConfigPath] is the path to the providers configuration file.
  DefaultProviderService({
    required ContextLogger logger,
    AssetBundle? assetBundle,
    String? providersConfigPath,
  }) : _logger = logger,
       _assetBundle = assetBundle ?? rootBundle,
       _providersConfigPath =
           providersConfigPath ?? 'assets/solid_providers.json';

  @override
  Future<List<Map<String, dynamic>>> loadProviders() async {
    try {
      final String jsonString = await _assetBundle.loadString(
        _providersConfigPath,
      );
      final data = json.decode(jsonString);
      return List<Map<String, dynamic>>.from(data['providers']);
    } catch (e, stackTrace) {
      _logger.error('Error loading providers', e, stackTrace);
      return [];
    }
  }
}
