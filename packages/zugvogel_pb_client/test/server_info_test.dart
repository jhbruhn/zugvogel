import 'package:flutter_test/flutter_test.dart';
import 'package:zugvogel_pb_client/zugvogel_pb_client.dart';

ServerInfo? parse(Object? json, {String service = 'testvogel'}) =>
    ServerInfo.tryParse(
      json,
      service: service,
      fallbackName: 'Testvogel',
    );

void main() {
  group('the identity marker', () {
    test('accepts a boolean marker under the service name', () {
      expect(parse({'testvogel': true, 'version': '1.2.3'}), isNotNull);
    });

    test('accepts the service key', () {
      expect(parse({'service': 'testvogel'}), isNotNull);
    });

    test('rejects a body with no marker at all', () {
      // A bare PocketBase, a reverse proxy, an unrelated 200.
      expect(parse({'version': '1.2.3'}), isNull);
      expect(parse({'service': 'something-else'}), isNull);
      expect(parse({'testvogel': false}), isNull);
    });

    test("rejects the OTHER Zugvogel app's backend", () {
      // The whole reason the marker is parameterised. Pointing eiermann at a
      // federfall server has to be a clean "not this backend" rather than a
      // client that half-works against the wrong schema.
      expect(parse({'service': 'federfall'}, service: 'eiermann'), isNull);
      expect(parse({'federfall': true}, service: 'eiermann'), isNull);
      expect(parse({'service': 'eiermann'}, service: 'eiermann'), isNotNull);
    });

    test('rejects a non-map body', () {
      expect(parse(null), isNull);
      expect(parse('ok'), isNull);
      expect(parse(<Object?>[]), isNull);
    });
  });

  group('fields', () {
    test('reads version, minClient and name', () {
      final info = parse({
        'service': 'testvogel',
        'version': '2.1.0',
        'minClient': '2.0.0',
        'name': 'Wildvogelhilfe Ost',
      })!;
      expect(info.version, '2.1.0');
      expect(info.minClient, '2.0.0');
      expect(info.name, 'Wildvogelhilfe Ost');
    });

    test('falls back to the injected name when the server sends none', () {
      // Not a hardcoded product name — boundary 1 applies to defaults too.
      expect(parse({'service': 'testvogel'})!.name, 'Testvogel');
    });

    test('a missing version is empty, not null — compatibility fails open', () {
      expect(parse({'service': 'testvogel'})!.version, '');
      expect(parse({'service': 'testvogel'})!.minClient, isNull);
    });
  });

  group('ServerAuthOptions', () {
    test('defaults to password-only when the server sends no auth block', () {
      final auth = parse({'service': 'testvogel'})!.auth;
      expect(auth.password, isTrue);
      expect(auth.oauth2, isEmpty);
      expect(auth.passwordReset, isFalse);
      expect(auth.selfSignup, isFalse);
    });

    test('reads providers and per-provider scopes', () {
      final auth = parse({
        'service': 'testvogel',
        'auth': {
          'password': false,
          'oauth2': ['oidc', 'github'],
          'oauth2Scopes': {
            'oidc': ['openid', 'groups'],
          },
          'passwordReset': true,
          'selfSignup': true,
        },
      })!.auth;
      expect(auth.password, isFalse);
      expect(auth.oauth2, ['oidc', 'github']);
      expect(auth.oauth2Scopes['oidc'], ['openid', 'groups']);
      expect(auth.oauth2Scopes['github'], isNull);
      expect(auth.passwordReset, isTrue);
      expect(auth.selfSignup, isTrue);
    });

    test('drops garbage entries rather than throwing', () {
      final auth = parse({
        'service': 'testvogel',
        'auth': {
          'oauth2': ['oidc', 42, null],
          'oauth2Scopes': {
            'oidc': ['openid', 7],
            'bad': 'not-a-list',
          },
        },
      })!.auth;
      expect(auth.oauth2, ['oidc']);
      expect(auth.oauth2Scopes['oidc'], ['openid']);
      expect(auth.oauth2Scopes.containsKey('bad'), isFalse);
    });

    test('equality is deep on the scope lists', () {
      // mapEquals would compare the List values by identity, so two equal
      // parses of the same JSON would come out different — and a provider
      // watching /info would rebuild on every fetch.
      final a = parse({
        'service': 'testvogel',
        'auth': {
          'oauth2Scopes': {
            'oidc': ['openid'],
          },
        },
      })!;
      final b = parse({
        'service': 'testvogel',
        'auth': {
          'oauth2Scopes': {
            'oidc': ['openid'],
          },
        },
      })!;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('scope-map hashing ignores key order', () {
      final a = ServerAuthOptions.fromJson(const {
        'oauth2Scopes': {
          'a': ['x'],
          'b': ['y'],
        },
      });
      final b = ServerAuthOptions.fromJson(const {
        'oauth2Scopes': {
          'b': ['y'],
          'a': ['x'],
        },
      });
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
