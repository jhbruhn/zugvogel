import 'package:flutter_test/flutter_test.dart';
import 'package:zugvogel_pb_client/zugvogel_pb_client.dart';

ServerInfo info(String version, {String? minClient}) => ServerInfo(
  version: version,
  name: 'Testvogel',
  auth: const ServerAuthOptions(),
  minClient: minClient,
);

ServerCompatibility check(String app, ServerInfo? server) =>
    checkServerCompatibility(appVersion: app, info: server);

void main() {
  group('matching majors interoperate', () {
    test('identical versions', () {
      expect(check('2.1.0', info('2.1.0')), ServerCompatibility.compatible);
    });

    test('minor and patch may differ in either direction', () {
      expect(check('2.0.0', info('2.9.9')), ServerCompatibility.compatible);
      expect(check('2.9.9', info('2.0.0')), ServerCompatibility.compatible);
    });
  });

  group('a major mismatch names the right party', () {
    test('an older app tells the user to update the app', () {
      expect(check('1.9.0', info('2.0.0')), ServerCompatibility.clientTooOld);
    });

    test('a newer app tells the OPERATOR to update the backend', () {
      // Telling this user to update their app would be a dead end — their app
      // is already the newer of the two. Unattended APK updaters make this the
      // common direction, not the exotic one.
      expect(check('3.0.0', info('2.0.0')), ServerCompatibility.serverTooOld);
    });
  });

  group('minClient is a finer floor on top of the major', () {
    test('below the floor is too old, even on a matching major', () {
      expect(
        check('2.0.0', info('2.5.0', minClient: '2.3.0')),
        ServerCompatibility.clientTooOld,
      );
    });

    test('at or above the floor is fine', () {
      expect(
        check('2.3.0', info('2.5.0', minClient: '2.3.0')),
        ServerCompatibility.compatible,
      );
      expect(
        check('2.4.0', info('2.5.0', minClient: '2.3.0')),
        ServerCompatibility.compatible,
      );
    });

    test('a pre-release suffix is not worth locking anyone out over', () {
      expect(
        check('2.3.0-rc1', info('2.5.0', minClient: '2.3.0')),
        ServerCompatibility.compatible,
      );
    });
  });

  group('it fails OPEN', () {
    // A false positive locks the user out of the app entirely, which is far
    // worse than letting a genuinely incompatible pair through to a clearer
    // runtime error. Every one of these must be `compatible`.
    test('discovery failed (null info)', () {
      expect(check('2.0.0', null), ServerCompatibility.compatible);
    });

    test('an unversioned dev build on either side', () {
      expect(check('0.0.0', info('2.0.0')), ServerCompatibility.compatible);
      expect(check('2.0.0', info('0.0')), ServerCompatibility.compatible);
      expect(check('2.0.0', info('0.0.0-dev')), ServerCompatibility.compatible);
      expect(check('0.0.0', info('0.0.0')), ServerCompatibility.compatible);
    });

    test('a version string that will not parse', () {
      expect(check('nightly', info('2.0.0')), ServerCompatibility.compatible);
      expect(check('2.0.0', info('unknown')), ServerCompatibility.compatible);
      expect(check('', info('2.0.0')), ServerCompatibility.compatible);
      expect(check('2.0.0', info('')), ServerCompatibility.compatible);
    });

    test('an unversioned minClient floor', () {
      expect(
        check('2.0.0', info('2.5.0', minClient: '0.0.0')),
        ServerCompatibility.compatible,
      );
    });
  });

  test('a short version is padded with zeroes (1.2 == 1.2.0)', () {
    expect(
      check('1.2', info('1.5.0', minClient: '1.2.0')),
      ServerCompatibility.compatible,
    );
    expect(
      check('1.2', info('1.5.0', minClient: '1.2.1')),
      ServerCompatibility.clientTooOld,
    );
  });
}
