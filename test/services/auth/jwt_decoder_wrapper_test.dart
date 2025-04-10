import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/services/auth/jwt_decoder_wrapper.dart';

void main() {
  late JwtDecoderWrapper jwtDecoder;

  setUp(() {
    jwtDecoder = JwtDecoderWrapper();
  });

  group('JwtDecoderWrapper', () {
    // Sample token for testing
    // This is a valid structure but with fabricated content for testing purposes only
    // Payload: {"sub":"1234567890","name":"Test User","iat":1516239022,"exp":9999999999}
    final String validToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IlRlc3QgVXNlciIsImlhdCI6MTUxNjIzOTAyMiwiZXhwIjo5OTk5OTk5OTk5fQ.'
        'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

    // Token with past expiration date
    // Payload: {"sub":"1234567890","name":"Test User","iat":1516239022,"exp":1516239023}
    final String expiredToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IlRlc3QgVXNlciIsImlhdCI6MTUxNjIzOTAyMiwiZXhwIjoxNTE2MjM5MDIzfQ.'
        'wV7CEgz1lgeuYoxDgHAkWUY9J8nUPCJLSXAFQFYsNbo';

    test('decode returns decoded token payload', () {
      final result = jwtDecoder.decode(validToken);

      expect(result, isA<Map<String, dynamic>>());
      expect(result['sub'], '1234567890');
      expect(result['name'], 'Test User');
      expect(result['iat'], 1516239022);
      expect(result['exp'], 9999999999);
    });

    test('isTokenExpired returns false for valid token', () {
      expect(jwtDecoder.isTokenExpired(validToken), false);
    });

    test('isTokenExpired returns true for expired token', () {
      expect(jwtDecoder.isTokenExpired(expiredToken), true);
    });

    test('getExpirationDate returns correct date', () {
      final expDate = jwtDecoder.getExpirationDate(validToken);

      // The token's expiration date is 9999999999 seconds since epoch
      final expectedDate = DateTime.fromMillisecondsSinceEpoch(
        9999999999 * 1000,
      );

      expect(expDate, expectedDate);
    });

    test('decode throws FormatException on invalid token', () {
      expect(() => jwtDecoder.decode('invalid.token'), throwsFormatException);
    });
  });
}
