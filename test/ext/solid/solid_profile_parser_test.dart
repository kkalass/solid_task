import 'package:flutter_test/flutter_test.dart';
import 'package:solid_task/ext/solid/pod/profile/default_solid_profile_parser.dart';
import 'package:solid_task/ext/solid/pod/profile/solid_profile_parser.dart';

void main() {
  group('DefaultProfileParser', () {
    late SolidProfileParser profileParser;
    const webId = 'https://example.com/profile/card#me';

    setUp(() {
      profileParser = DefaultSolidProfileParser();
    });

    test('parses Turtle profile with solid:storage', () async {
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

      final result = await profileParser.parseStorageUrl(
        webId,
        turtleProfile,
        'text/turtle',
      );
      expect(result, 'https://example.com/storage/');
    });

    test('parses real life Turtle profile with solid:storage', () async {
      const turtleProfile = '''
@prefix : <#>.
@prefix acl: <http://www.w3.org/ns/auth/acl#>.
@prefix foaf: <http://xmlns.com/foaf/0.1/>.
@prefix ldp: <http://www.w3.org/ns/ldp#>.
@prefix schema: <http://schema.org/>.
@prefix solid: <http://www.w3.org/ns/solid/terms#>.
@prefix space: <http://www.w3.org/ns/pim/space#>.
@prefix pro: <./>.
@prefix inbox: </inbox/>.
@prefix kk: </>.

pro:card a foaf:PersonalProfileDocument; foaf:maker :me; foaf:primaryTopic :me.

:me
    a schema:Person, foaf:Person;
    acl:trustedApp
            [
                acl:mode acl:Append, acl:Read, acl:Write;
                acl:origin <http://localhost:4400>
            ],
            [
                acl:mode acl:Append, acl:Read, acl:Write;
                acl:origin <http://localhost:52927>
            ];
    ldp:inbox inbox:;
    space:preferencesFile </settings/prefs.ttl>;
    space:storage kk:;
    solid:account kk:;
    solid:oidcIssuer <https://datapod.igrant.io>;
    solid:privateTypeIndex </settings/privateTypeIndex.ttl>;
    solid:publicTypeIndex </settings/publicTypeIndex.ttl>;
    foaf:name "Klas Kala\u00df".
''';

      final result = await profileParser.parseStorageUrl(
        'https://kkalass.datapod.igrant.io/profile/card#me',
        turtleProfile,
        'text/turtle',
      );
      expect(result, 'https://kkalass.datapod.igrant.io/');
    });

    test('parses real lifeJSON-LD profile', () async {
      const jsonLdProfile = '''
[
  {
    "@id": "_:b1__g_L16C502",
    "http://www.w3.org/ns/auth/acl#mode": [
      {
        "@id": "http://www.w3.org/ns/auth/acl#Append"
      },
      {
        "@id": "http://www.w3.org/ns/auth/acl#Read"
      },
      {
        "@id": "http://www.w3.org/ns/auth/acl#Write"
      }
    ],
    "http://www.w3.org/ns/auth/acl#origin": [
      {
        "@id": "http://localhost:4400"
      }
    ]
  },
  {
    "@id": "_:b1__g_L20C640",
    "http://www.w3.org/ns/auth/acl#mode": [
      {
        "@id": "http://www.w3.org/ns/auth/acl#Append"
      },
      {
        "@id": "http://www.w3.org/ns/auth/acl#Read"
      },
      {
        "@id": "http://www.w3.org/ns/auth/acl#Write"
      }
    ],
    "http://www.w3.org/ns/auth/acl#origin": [
      {
        "@id": "http://localhost:52927"
      }
    ]
  },
  {
    "@id": "https://kkalass.datapod.igrant.io/profile/card",
    "@type": [
      "http://xmlns.com/foaf/0.1/PersonalProfileDocument"
    ],
    "http://xmlns.com/foaf/0.1/maker": [
      {
        "@id": "https://kkalass.datapod.igrant.io/profile/card#me"
      }
    ],
    "http://xmlns.com/foaf/0.1/primaryTopic": [
      {
        "@id": "https://kkalass.datapod.igrant.io/profile/card#me"
      }
    ]
  },
  {
    "@id": "https://kkalass.datapod.igrant.io/profile/card#me",
    "@type": [
      "http://schema.org/Person",
      "http://xmlns.com/foaf/0.1/Person"
    ],
    "http://www.w3.org/ns/auth/acl#trustedApp": [
      {
        "@id": "_:b1__g_L16C502"
      },
      {
        "@id": "_:b1__g_L20C640"
      }
    ],
    "http://www.w3.org/ns/ldp#inbox": [
      {
        "@id": "https://kkalass.datapod.igrant.io/inbox/"
      }
    ],
    "http://www.w3.org/ns/pim/space#preferencesFile": [
      {
        "@id": "https://kkalass.datapod.igrant.io/settings/prefs.ttl"
      }
    ],
    "http://www.w3.org/ns/pim/space#storage": [
      {
        "@id": "https://kkalass.datapod.igrant.io/"
      }
    ],
    "http://www.w3.org/ns/solid/terms#account": [
      {
        "@id": "https://kkalass.datapod.igrant.io/"
      }
    ],
    "http://www.w3.org/ns/solid/terms#oidcIssuer": [
      {
        "@id": "https://datapod.igrant.io"
      }
    ],
    "http://www.w3.org/ns/solid/terms#privateTypeIndex": [
      {
        "@id": "https://kkalass.datapod.igrant.io/settings/privateTypeIndex.ttl"
      }
    ],
    "http://www.w3.org/ns/solid/terms#publicTypeIndex": [
      {
        "@id": "https://kkalass.datapod.igrant.io/settings/publicTypeIndex.ttl"
      }
    ],
    "http://xmlns.com/foaf/0.1/name": [
      {
        "@value": "Klas Kalaß"
      }
    ]
  }
]
''';

      final result = await profileParser.parseStorageUrl(
        webId,
        jsonLdProfile,
        'application/ld+json',
      );
      expect(result, 'https://kkalass.datapod.igrant.io/');
    });

    test('parses JSON-LD profile with solid:storage', () async {
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

      final result = await profileParser.parseStorageUrl(
        webId,
        jsonLdProfile,
        'application/ld+json',
      );
      expect(result, 'https://example.com/storage/');
    });
    test('parses JSON-LD profile with @graph structure', () async {
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

      final result = await profileParser.parseStorageUrl(
        webId,
        jsonLdGraphProfile,
        'application/ld+json',
      );
      expect(result, 'https://example.com/storage/');
    });

    test('parses JSON-LD profile with compact IRIs', () async {
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

      final result = await profileParser.parseStorageUrl(
        webId,
        jsonLdCompactProfile,
        'application/ld+json',
      );
      expect(result, 'https://example.com/storage/');
    });

    test('handles invalid JSON-LD gracefully', () async {
      final result = await profileParser.parseStorageUrl(
        webId,
        'invalid json',
        'application/ld+json',
      );
      expect(result, isNull);
    });

    test('handles invalid Turtle gracefully', () async {
      final result = await profileParser.parseStorageUrl(
        webId,
        'invalid turtle',
        'text/turtle',
      );
      expect(result, isNull);
    });

    test('tries both formats when content type is unknown', () async {
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

      final result = await profileParser.parseStorageUrl(
        webId,
        jsonLdProfile,
        'application/octet-stream',
      );
      expect(result, 'https://example.com/storage/');
    });
  });
}
