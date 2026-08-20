import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:zugvogel_pb_client/zugvogel_pb_client.dart';

import 'support/config.dart';

ServerProbe probeWith(
  Future<Object?> Function(String) prober, {
  bool allowInsecureHttp = false,
}) => ServerProbe(
  config: testConfig(allowInsecureHttp: allowInsecureHttp),
  prober: prober,
);

Future<Object?> answersOk(String _) async => {
  'service': 'testvogel',
  'version': '1.0.0',
};

void main() {
  group('normalizeServerUrl', () {
    test('assumes https when no scheme is given', () {
      expect(normalizeServerUrl('pigeons.example'), 'https://pigeons.example');
      expect(
        normalizeServerUrl('192.168.1.5:8090'),
        'https://192.168.1.5:8090',
      );
    });

    test('trims, and drops trailing slashes', () {
      expect(
        normalizeServerUrl('  https://a.example/  '),
        'https://a.example',
      );
      expect(normalizeServerUrl('https://a.example///'), 'https://a.example');
    });

    test('preserves an explicit port and a sub-path', () {
      // Some self-hosters run PocketBase under a path.
      expect(
        normalizeServerUrl('https://a.example:8443/pb'),
        'https://a.example:8443/pb',
      );
    });

    test('drops query and fragment', () {
      expect(
        normalizeServerUrl('https://a.example/pb?x=1#top'),
        'https://a.example/pb',
      );
    });

    test('rejects anything that cannot be an http(s) URL', () {
      expect(normalizeServerUrl(''), isNull);
      expect(normalizeServerUrl('   '), isNull);
      expect(normalizeServerUrl('ftp://a.example'), isNull);
      expect(normalizeServerUrl('file:///etc/passwd'), isNull);
      expect(normalizeServerUrl('https://'), isNull);
    });
  });

  group('cleartext http', () {
    test('is rejected for a non-loopback host', () async {
      // http sends the bearer token in cleartext. The OS blocks it in release
      // builds anyway, which surfaces as an opaque connection failure — this
      // rejects it with a reason the UI can phrase.
      expect(
        await probeWith(answersOk).probe('http://pigeons.example'),
        isA<ProbeInsecureHttp>(),
      );
    });

    test('is always allowed on loopback, whatever the flavor', () async {
      for (final host in ['localhost', '127.0.0.1']) {
        expect(
          await probeWith(answersOk).probe('http://$host:8090'),
          isA<ProbeReachable>(),
          reason: host,
        );
      }
    });

    test('is allowed on the local network when the app opts in', () async {
      // A development flavor sets allowInsecureHttp so it can reach a
      // plain-http PocketBase on the LAN.
      expect(
        await probeWith(
          answersOk,
          allowInsecureHttp: true,
        ).probe('http://192.168.1.5:8090'),
        isA<ProbeReachable>(),
      );
    });

    test('https is never affected by the opt-in', () async {
      expect(
        await probeWith(answersOk).probe('https://pigeons.example'),
        isA<ProbeReachable>(),
      );
    });
  });

  group('classifying what answered', () {
    test(
      'a matching server is reachable, with its info and normalised URL',
      () async {
        final result = await probeWith(answersOk).probe('pigeons.example/');
        expect(result, isA<ProbeReachable>());
        final reachable = result as ProbeReachable;
        expect(reachable.baseUrl, 'https://pigeons.example');
        expect(reachable.info.version, '1.0.0');
      },
    );

    test(
      'a generic PocketBase (404 on the route) is the wrong service',
      () async {
        final result = await probeWith(
          (_) async => throw ClientException(statusCode: 404),
        ).probe('pigeons.example');
        expect(result, isA<ProbeWrongService>());
      },
    );

    test('a 200 with no marker is the wrong service', () async {
      final result = await probeWith(
        (_) async => {'hello': 'world'},
      ).probe('pigeons.example');
      expect(result, isA<ProbeWrongService>());
    });

    test("the other app's backend is the wrong service", () async {
      final result = await probeWith(
        (_) async => {'service': 'federfall', 'version': '1.4.1'},
      ).probe('pigeons.example');
      expect(result, isA<ProbeWrongService>());
    });

    test('no HTTP response at all (status 0) is unreachable', () async {
      // Connection refused, DNS failure, aborted request.
      final result = await probeWith(
        (_) async => throw ClientException(),
      ).probe('pigeons.example');
      expect(result, isA<ProbeUnreachable>());
    });

    test('a timeout is unreachable, not a wrong service', () async {
      final result = await probeWith(
        (_) async => throw TimeoutException('slow'),
      ).probe('pigeons.example');
      expect(result, isA<ProbeUnreachable>());
    });

    test('an unparseable URL never reaches the network', () async {
      var called = false;
      final result = await probeWith((_) async {
        called = true;
        return null;
      }).probe('ftp://nope');
      expect(result, isA<ProbeInvalidUrl>());
      expect(called, isFalse);
    });
  });
}
