import 'package:flutter_test/flutter_test.dart';
import 'package:my_cross_platform_app/services/profile_parser.dart';

void main() {
  group('ProfileParser', () {
    const webId = 'https://example.com/profile/card#me';

    // Example Turtle profile with various storage predicates
    const turtleProfile = '''
@prefix solid: <http://www.w3.org/ns/solid/terms#>.
@prefix space: <http://www.w3.org/ns/pim/space#>.
@prefix ldp: <http://www.w3.org/ns/ldp#>.
@prefix pim: <http://www.w3.org/ns/pim/space#>.

<https://example.com/profile/card#me>
    solid:storage <https://example.com/storage/>;
    space:storage <https://example.com/storage/>;
    ldp:contains <https://example.com/storage/>;
    solid:oidcIssuer <https://example.com/>;
    solid:account <https://example.com/account/>;
    solid:storageLocation <https://example.com/storage/>.

<https://example.com/storage/>
    a solid:StorageContainer.
''';

    // Example JSON-LD profile
    const jsonLdProfile = '''
{
  "@context": {
    "solid": "http://www.w3.org/ns/solid/terms#",
    "space": "http://www.w3.org/ns/pim/space#",
    "ldp": "http://www.w3.org/ns/ldp#"
  },
  "@id": "https://example.com/profile/card#me",
  "solid:storage": "https://example.com/storage/",
  "space:storage": "https://example.com/storage/",
  "ldp:contains": "https://example.com/storage/",
  "solid:oidcIssuer": "https://example.com/",
  "solid:account": "https://example.com/account/",
  "solid:storageLocation": "https://example.com/storage/"
}
''';

    // Example profile with @graph structure
    const jsonLdGraphProfile = '''
{
  "@context": {
    "solid": "http://www.w3.org/ns/solid/terms#",
    "space": "http://www.w3.org/ns/pim/space#"
  },
  "@graph": [
    {
      "@id": "https://example.com/profile/card#me",
      "solid:storage": "https://example.com/storage/"
    },
    {
      "@id": "https://example.com/storage/",
      "@type": "solid:StorageContainer"
    }
  ]
}
''';

    // Example profile with compact IRIs
    const jsonLdCompactProfile = '''
{
  "@context": {
    "solid": "http://www.w3.org/ns/solid/terms#",
    "space": "http://www.w3.org/ns/pim/space#"
  },
  "@id": "https://example.com/profile/card#me",
  "solid:storage": {
    "@id": "https://example.com/storage/"
  }
}
''';

    test('parses Turtle profile with solid:storage', () async {
      final result = await ProfileParser.parseProfile(
        webId,
        turtleProfile,
        'text/turtle',
      );
      expect(result, 'https://example.com/storage/');
    });

    test('parses JSON-LD profile with solid:storage', () async {
      final result = await ProfileParser.parseProfile(
        webId,
        jsonLdProfile,
        'application/ld+json',
      );
      expect(result, 'https://example.com/storage/');
    });

    test('parses JSON-LD profile with @graph structure', () async {
      final result = await ProfileParser.parseProfile(
        webId,
        jsonLdGraphProfile,
        'application/ld+json',
      );
      expect(result, 'https://example.com/storage/');
    });

    test('parses JSON-LD profile with compact IRIs', () async {
      final result = await ProfileParser.parseProfile(
        webId,
        jsonLdCompactProfile,
        'application/ld+json',
      );
      expect(result, 'https://example.com/storage/');
    });

    test('handles invalid JSON-LD gracefully', () async {
      final result = await ProfileParser.parseProfile(
        webId,
        'invalid json',
        'application/ld+json',
      );
      expect(result, isNull);
    });

    test('handles invalid Turtle gracefully', () async {
      final result = await ProfileParser.parseProfile(
        webId,
        'invalid turtle',
        'text/turtle',
      );
      expect(result, isNull);
    });

    test('tries both formats when content type is unknown', () async {
      final result = await ProfileParser.parseProfile(
        webId,
        jsonLdProfile,
        'application/octet-stream',
      );
      expect(result, 'https://example.com/storage/');
    });
  });
}
