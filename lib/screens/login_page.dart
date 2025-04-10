import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/service_locator.dart';
import '../services/auth/auth_service.dart';

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
  final _authService = sl<AuthService>();

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      final providers = await _authService.loadProviders();
      setState(() {
        _providers = providers;
      });
    } catch (e) {
      // Error is already logged in the auth service
    }
  }

  Future<void> _login(String input) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String issuerUri = await _authService.getIssuer(input.trim());

      if (!mounted) return;

      final result = await _authService.authenticate(issuerUri, context);

      if (!mounted) return;

      if (result.isSuccess) {
        Navigator.of(context).pop(result);
      } else {
        setState(() {
          _errorMessage = AppLocalizations.of(
            context,
          )!.errorConnectingSolid(result.error!);
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = AppLocalizations.of(
          context,
        )!.errorConnectingSolid(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                  backgroundColor: colorScheme.surfaceContainerHighest,
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
          onFieldSubmitted: (value) => _login(value),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _isLoading ? null : () => _login(_urlController.text),
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
          onPressed: () async {
            final podUrl = await _authService.getNewPodUrl();
            if (context.mounted) {
              launchUrl(Uri.parse(podUrl));
            }
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
