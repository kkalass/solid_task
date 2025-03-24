import 'package:flutter/material.dart';
import 'package:solid_auth/solid_auth.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'items_screen.dart';

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

      if (!mounted) return;
      Navigator.of(context).pop({
        'webId': webId,
        'accessToken': accessToken,
        'decodedToken': decodedToken,
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error connecting to Solid: $e';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Connect to Solid Pod',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon and description
              Icon(
                Icons.cloud_sync_rounded,
                size: 64,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Sync your tasks across devices',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Enter your WebID or Solid Pod issuer URL to enable cloud synchronization',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Input field
              TextFormField(
                key: _formKey,
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'Enter your WebID or Pod URL',
                  helperText:
                      'e.g., https://your-pod-provider.com/profile/card#me',
                  helperMaxLines: 2,
                  helperStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  prefixIcon: const Icon(Icons.link_rounded),
                  filled: true,
                  fillColor: colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  errorText: _errorMessage,
                  errorMaxLines: 3,
                ),
                enabled: !_isLoading,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onFieldSubmitted: (value) {
                  if (value.isNotEmpty) {
                    _login(value);
                  }
                },
              ),
              const SizedBox(height: 24),

              // Connect button
              FilledButton(
                onPressed:
                    _isLoading ? null : () => _login(_urlController.text),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Text(
                          'Connect',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),

              // Help text
              if (!_isLoading) ...[
                const SizedBox(height: 24),
                Text(
                  'Don\'t have a Solid Pod yet?',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Add link to Solid Pod providers
                  },
                  child: const Text('Get one here'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}
