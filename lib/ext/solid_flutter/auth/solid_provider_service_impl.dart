import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:solid_task/ext/solid/auth/interfaces/solid_provider_service.dart';

final _log = Logger("solid_flutter");

/// Implementation of the ProviderService that loads providers from an asset file
class SolidProviderServiceImpl implements SolidProviderService {
  final AssetBundle _assetBundle;

  /// Path to the providers configuration file
  final String _providersConfigPath;

  /// Creates a new DefaultProviderService with required dependencies.
  ///
  /// The [logger] is used for logging operations.
  /// The [assetBundle] is used to load assets.
  /// The [providersConfigPath] is the path to the providers configuration file.
  SolidProviderServiceImpl({
    AssetBundle? assetBundle,
    String? providersConfigPath,
  }) : _assetBundle = assetBundle ?? rootBundle,
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
      _log.severe('Error loading providers', e, stackTrace);
      return [];
    }
  }

  @override
  Future<String> getNewPodUrl() async {
    try {
      final String jsonString = await _assetBundle.loadString(
        _providersConfigPath,
      );
      final data = json.decode(jsonString);
      final config = data['config'] as Map<String, dynamic>?;

      if (config != null && config.containsKey('getPodUrl')) {
        return config['getPodUrl'] as String;
      } else {
        _log.warning('getPodUrl not found in config, using default value');
        // Default fallback URL
        return 'https://solidproject.org/users/get-a-pod';
      }
    } catch (e, stackTrace) {
      _log.severe('Error loading Pod URL from configuration', e, stackTrace);
      // Default fallback URL in case of error
      return 'https://solidproject.org/users/get-a-pod';
    }
  }
}
