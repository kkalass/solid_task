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

      // Define scopes. Also possible scopes -> webid, email, api
      final List<String> scopes = <String>[
        'openid',
        'profile',
        'offline_access',
      ];

      if (!mounted) return;

      // Authentication process for the POD issuer
      var authData = await authenticate(Uri.parse(issuerUri), scopes, context);

      // Decode access token to recheck the WebID
      String accessToken = authData['accessToken'];
      Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);
      String webId = decodedToken['webid'];

      if (!mounted) return;
      // Navigate to Items screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (context) => ItemsScreen(
                webId: webId,
                accessToken: accessToken,
                decodedToken: decodedToken,
              ),
        ),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Solid'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enter your WebID or issuer',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: _formKey,
              controller: _urlController,
              decoration: InputDecoration(
                hintText:
                    'e.g., https://kkalass.datapod.igrant.io/profile/card#me',
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:
                    _isLoading ? null : () => _login(_urlController.text),
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Connect to Solid'),
              ),
            ),
          ],
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
