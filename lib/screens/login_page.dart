import 'package:flutter/material.dart';
import 'package:solid_auth/solid_auth.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../services/profile_parser.dart';
import '../services/logger_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormFieldState>();
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>>? _providers;
  final _logger = LoggerService();

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      final String jsonString = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/solid_providers.json');
      final data = json.decode(jsonString);
      setState(() {
        _providers = List<Map<String, dynamic>>.from(data['providers']);
      });
    } catch (e, stackTrace) {
      _logger.error('Error loading providers', e, stackTrace);
    }
  }

  Future<String?> _getPodUrl(String webId) async {
    try {
      final response = await http.get(
        Uri.parse(webId),
        headers: {
          'Accept': 'text/turtle, application/ld+json;q=0.9, */*;q=0.8',
        },
      );

      if (response.statusCode != 200) {
        _logger.warning('Failed to fetch profile: ${response.statusCode}');
        return null;
      }

      final contentType = response.headers['content-type'] ?? '';
      final data = response.body;

      return await ProfileParser.parseProfile(webId, data, contentType);
    } catch (e, stackTrace) {
      _logger.error('Error fetching pod URL', e, stackTrace);
      return null;
    }
  }

  Future<void> _login(String input) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String issuerUri = await getIssuer(input.trim());
      final List<String> scopes = <String>[
        'openid',
        'profile',
        'offline_access',
      ];

      if (!mounted) return;

      var authData = await authenticate(Uri.parse(issuerUri), scopes, context);
      String accessToken = authData['accessToken'];
      Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);
      String webId = decodedToken['webid'];
      _logger.info('Auth data: $authData');
      _logger.info('Decoded token: $decodedToken');
      var profilePage = await fetchProfileData(webId);

      _logger.info('Profile page: $profilePage');
      var podUrl = await _getPodUrl(webId);
      _logger.info('Pod URL: $podUrl');
      if (!mounted) return;
      Navigator.of(context).pop({
        'webId': webId,
        'accessToken': accessToken,
        'decodedToken': decodedToken,
        authData: authData,
      });
    } catch (e, stackTrace) {
      _logger.error('Login error', e, stackTrace);
      setState(() {
        _errorMessage = AppLocalizations.of(
          context,
        )!.errorConnectingSolid(e.toString());
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    Widget loginContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.cloud_sync_rounded, size: 48, color: colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          l10n.syncAcrossDevices,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Quick access provider buttons
        if (_providers != null) ...[
          Text(
            l10n.chooseProvider,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ..._providers!.map(
            (provider) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _login(provider['url']),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  backgroundColor: colorScheme.surfaceVariant,
                ),
                child: Text(provider['name']),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
        ],

        // Manual WebID input
        Text(
          l10n.orEnterManually,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: _formKey,
          controller: _urlController,
          decoration: InputDecoration(
            hintText: l10n.webIdHint,
            errorText: _errorMessage,
            errorMaxLines: 2,
          ),
          enabled: !_isLoading,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed:
              _isLoading
                  ? null
                  : () {
                    if (_urlController.text.isNotEmpty) {
                      _login(_urlController.text);
                    }
                  },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : Text(l10n.connect),
        ),

        // "Get a Pod" section
        const SizedBox(height: 24),
        Text(
          l10n.noPod,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: () {
            launchUrl(Uri.parse('https://solidproject.org/users/get-a-pod'));
          },
          child: Text(l10n.getPod),
        ),
      ],
    );

    // For wider screens, wrap the content in a constrained box
    if (isWideScreen) {
      loginContent = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: loginContent,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.connectToSolid,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isWideScreen ? 24 : 16,
          vertical: 24,
        ),
        child: loginContent,
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}
