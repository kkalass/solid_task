/// Service for loading and managing SOLID providers
abstract class ProviderService {
  /// Loads the list of SOLID identity providers from the configuration
  Future<List<Map<String, dynamic>>> loadProviders();
}
