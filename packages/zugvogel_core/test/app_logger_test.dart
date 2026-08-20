import 'package:test/test.dart';
import 'package:zugvogel_core/zugvogel_core.dart';

void main() {
  group('scrubLogPayload', () {
    test('redacts a protected-file token in a query string', () {
      // ClientException.toString() carries the full request URL, and a
      // PocketBase protected-file URL carries a short-lived token.
      expect(
        scrubLogPayload('GET /api/files/x/y.jpg?token=eyJhbGciOi.abc-_1'),
        'GET /api/files/x/y.jpg?token=***',
      );
      expect(
        scrubLogPayload('...?thumb=100x100&token=secret&x=1'),
        '...?thumb=100x100&token=***&x=1',
      );
    });

    test('redacts a Bearer header, whatever its casing', () {
      expect(
        scrubLogPayload('Authorization: Bearer eyJhbGciOiJIUzI1'),
        'Authorization: Bearer ***',
      );
      expect(
        scrubLogPayload('authorization: bearer eyJhbGciOiJIUzI1'),
        'authorization: bearer ***',
      );
    });

    test('redacts PII echoed back in a JSON validation body', () {
      expect(
        scrubLogPayload('{"phone":"0176 1234567","code":"invalid"}'),
        '{"phone":***,"code":"invalid"}',
      );
      expect(
        scrubLogPayload('{"email":"a@b.de","first_name":"Ada"}'),
        '{"email":***,"first_name":***}',
      );
    });

    test('redacts PII in the Map.toString() shape too', () {
      expect(
        scrubLogPayload('{last_name: Lovelace, id: abc}'),
        '{last_name: ***, id: abc}',
      );
    });

    test('an app can extend the key list', () {
      expect(
        scrubLogPayload('{"iban":"DE02..."}', piiKeys: ['iban']),
        '{"iban":***}',
      );
      // ...and the default keys are a floor, not a ceiling: passing a list
      // replaces it, which is why the default is exported.
      expect(
        scrubLogPayload(
          '{"iban":"DE02...","phone":"0176"}',
          piiKeys: [...defaultPiiLogKeys, 'iban'],
        ),
        '{"iban":***,"phone":***}',
      );
    });

    test('leaves an ordinary message untouched', () {
      expect(scrubLogPayload('loaded 12 records'), 'loaded 12 records');
    });
  });

  group('AppLogger', () {
    test('drops messages below minLevel', () {
      // No sink to assert against (dart:developer writes to the VM service),
      // so this pins the gate itself rather than the output.
      const quiet = AppLogger(minLevel: LogLevel.warning);
      expect(quiet.minLevel.value, LogLevel.warning.value);
      expect(LogLevel.debug.value < quiet.minLevel.value, isTrue);
      expect(LogLevel.info.value < quiet.minLevel.value, isTrue);
      expect(LogLevel.error.value < quiet.minLevel.value, isFalse);
    });

    test('level values match dart:developer conventions', () {
      expect(LogLevel.debug.value, 500);
      expect(LogLevel.info.value, 800);
      expect(LogLevel.warning.value, 900);
      expect(LogLevel.error.value, 1000);
    });

    test('the channel is injected, and defaults to something neutral', () {
      // Injection boundary 3: the package cannot know an app's name.
      expect(const AppLogger().channel, 'app');
      expect(const AppLogger(channel: 'eiermann').channel, 'eiermann');
    });

    test('logging does not throw for any level', () {
      const log = AppLogger();
      expect(() => log.debug('d'), returnsNormally);
      expect(() => log.info('i'), returnsNormally);
      expect(() => log.warning('w', error: 'e'), returnsNormally);
      expect(
        () => log.error('e', error: 'e', stackTrace: StackTrace.current),
        returnsNormally,
      );
    });
  });

  group('reportCaughtError', () {
    tearDown(() => rootLogger = const AppLogger());

    test('routes through rootLogger, so bootstrap can swap the sink', () {
      // The seam a crash reporter hooks into: replacing rootLogger is enough
      // to see errors reported from outside the provider graph.
      rootLogger = const AppLogger(minLevel: LogLevel.error);
      expect(
        () => reportCaughtError(StateError('x'), StackTrace.current),
        returnsNormally,
      );
    });
  });
}
