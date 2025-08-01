import 'package:flutter/foundation.dart';

class AppConfig {
  // Web redirect URLs
  static const String webRedirectPathDevelopment = '/redirect.html';
  static const String webRedirectPathProduction = '/redirect.html';

  // Production domain (update this when you deploy)
  static const String productionDomain = 'https://kkalass.github.io/solid_task';

  // Development port detection
  static const int defaultWebPort = 3000;

  // Custom URL schemes
  static const String urlScheme = 'de.kalass.solidtask';

  // Static client ID pointing to our Public Client Identifier Document
  static const String oidcClientId =
      'https://kkalass.github.io/solid_task/client-identifier.jsonld';

  /// Gets the appropriate web redirect URL based on environment
  static Uri getWebRedirectUrl() {
    if (kDebugMode) {
      // In development, try to detect the actual port
      final port = _detectWebPort();
      return Uri.parse('http://localhost:$port$webRedirectPathDevelopment');
    } else {
      return Uri.parse('$productionDomain$webRedirectPathProduction');
    }
  }

  /// Attempts to detect the actual web development port
  static int _detectWebPort() {
    // Unfortunately, there's no reliable way to detect the port at runtime
    // Flutter web dev server port is determined at build time
    // Options:
    // 1. Use default port (3000)
    // 2. Use environment variable
    // 3. Use build-time configuration

    // Check for environment variable first
    const portFromEnv = String.fromEnvironment('WEB_PORT');
    if (portFromEnv.isNotEmpty) {
      return int.tryParse(portFromEnv) ?? defaultWebPort;
    }

    return defaultWebPort;
  }
}
