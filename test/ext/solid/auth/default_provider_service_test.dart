import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:solid_task/ext/solid_flutter/auth/solid_provider_service_impl.dart';

@GenerateMocks([AssetBundle])
import 'default_provider_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DefaultProviderService', () {
    late MockAssetBundle mockAssetBundle;
    late SolidProviderServiceImpl providerService;

    setUp(() {
      mockAssetBundle = MockAssetBundle();

      providerService = SolidProviderServiceImpl(assetBundle: mockAssetBundle);
    });

    test('loadProviders returns providers from asset file', () async {
      // Setup
      const providersJson = '''
      {
        "providers": [
          {"name": "Provider 1", "url": "https://provider1.example"},
          {"name": "Provider 2", "url": "https://provider2.example"}
        ]
      }
      ''';

      when(
        mockAssetBundle.loadString('assets/solid_providers.json'),
      ).thenAnswer((_) async => providersJson);

      // Execute
      final providers = await providerService.loadProviders();

      // Verify
      expect(providers.length, 2);
      expect(providers[0]['name'], 'Provider 1');
      expect(providers[0]['url'], 'https://provider1.example');
      expect(providers[1]['name'], 'Provider 2');
      expect(providers[1]['url'], 'https://provider2.example');
      verify(
        mockAssetBundle.loadString('assets/solid_providers.json'),
      ).called(1);
    });

    test('loadProviders handles errors gracefully', () async {
      // Setup - force an error
      when(
        mockAssetBundle.loadString(any),
      ).thenThrow(Exception('Asset not found'));

      // Execute
      final providers = await providerService.loadProviders();

      // Verify
      expect(providers, isEmpty);
    });

    test('loadProviders uses custom path when provided', () async {
      // Setup
      const customPath = 'assets/custom_providers.json';
      const providersJson =
          '{"providers": [{"name": "Custom", "url": "https://custom.example"}]}';

      providerService = SolidProviderServiceImpl(
        assetBundle: mockAssetBundle,
        providersConfigPath: customPath,
      );

      when(
        mockAssetBundle.loadString(customPath),
      ).thenAnswer((_) async => providersJson);

      // Execute
      final providers = await providerService.loadProviders();

      // Verify
      expect(providers.length, 1);
      expect(providers[0]['name'], 'Custom');
      verify(mockAssetBundle.loadString(customPath)).called(1);
    });
  });
}
