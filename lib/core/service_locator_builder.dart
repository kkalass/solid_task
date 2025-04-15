/// Provides a fluent API for building and configuring the service locator.
/// The idea here is, that we create extensions for this builder and
///  allow extensions to add their own services to the locator.
class ServiceLocatorBuilder {
  // List of extension build hooks to be executed during build
  final List<Future<void> Function()> _buildHooks = [];

  /// Register a build hook from an extension
  ///
  /// This allows extensions to add their own registration logic to be
  /// executed during the build phase.
  void registerBuildHook(Future<void> Function() hook) {
    _buildHooks.add(hook);
  }

  /// Builds and initializes the service locator with all configured services
  Future<void> build() async {
    // Execute any registered extension build hooks in the order they were
    // registered
    for (final hook in _buildHooks) {
      await hook();
    }
  }
}
