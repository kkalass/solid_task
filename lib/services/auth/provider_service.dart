/// Service for loading and managing SOLID providers
abstract class ProviderService {
  /// Loads the list of SOLID identity providers from the configuration
  Future<List<Map<String, dynamic>>> loadProviders();

  /// Returns the URL for obtaining a new SOLID Pod
  Future<String> getNewPodUrl();
}
