class LoginResult {
  final String? webId;
  final String? podUrl;
  final String? accessToken;
  final Map<String, dynamic>? decodedToken;
  final Map<String, dynamic>? authData;
  final String? error;

  const LoginResult({
    this.webId,
    this.podUrl,
    this.accessToken,
    this.decodedToken,
    this.authData,
    this.error,
  });

  factory LoginResult.error(String errorMessage) {
    return LoginResult(error: errorMessage);
  }

  bool get isSuccess => error == null;

  Map<String, dynamic> toMap() {
    return {
      'webId': webId,
      'podUrl': podUrl,
      'accessToken': accessToken,
      'decodedToken': decodedToken,
      'authData': authData,
    };
  }
}
