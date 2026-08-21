import 'package:pocketbase/pocketbase.dart';
import 'package:test/test.dart';
import 'package:zugvogel_data/zugvogel_data.dart';

void main() {
  group('RepositoryException.fromClient', () {
    RepositoryException of(int status) =>
        RepositoryException.fromClient(ClientException(statusCode: status));

    test('classifies by status code', () {
      expect(of(0).kind, RepositoryErrorKind.network);
      expect(of(0).isNetwork, isTrue);
      expect(of(401).kind, RepositoryErrorKind.unauthorized);
      expect(of(403).kind, RepositoryErrorKind.unauthorized);
      expect(of(404).kind, RepositoryErrorKind.notFound);
      expect(of(400).kind, RepositoryErrorKind.validation);
      expect(of(422).kind, RepositoryErrorKind.validation);
      expect(of(500).kind, RepositoryErrorKind.unknown);
    });

    test('preserves status and cause', () {
      final e = of(404);
      expect(e.statusCode, 404);
      expect(e.cause, isA<ClientException>());
    });

    test('never produces unknownOutcome — a ClientException means the '
        'server answered', () {
      for (final status in [0, 400, 401, 403, 404, 422, 500, 503]) {
        expect(of(status).kind, isNot(RepositoryErrorKind.unknownOutcome));
      }
    });

    test('toString names the kind and status, for a log line', () {
      expect(of(404).toString(), contains('notFound'));
      expect(of(404).toString(), contains('404'));
    });
  });

  group('serverCodes — what a hook is allowed to send', () {
    RepositoryException from(int status, Map<String, dynamic> response) =>
        RepositoryException.fromClient(
          ClientException(statusCode: status, response: response),
        );

    test('a hook refusal carries its code, as the KEY of data', () {
      // The key is the ONLY part of `data` PocketBase leaves alone: it
      // rewrites every value to {code: "validation_invalid_value", …} at any
      // depth, and re-coerces even an already correctly-shaped {code, message}
      // one level deeper. Measured against 0.39.8.
      final e = from(400, {
        'data': {'spot_phase_needs_permitted': 1},
        'message': 'spot phase requires prospect_stage=permitted',
        'status': 400,
      });
      expect(e.kind, RepositoryErrorKind.validation);
      expect(e.serverCodes, ['spot_phase_needs_permitted']);
    });

    test('several codes come through in order, first match wins upstream', () {
      final e = from(400, {
        'data': {'visit_nest_foreign': 1, 'visit_nest_duplicate': 1},
      });
      expect(e.serverCodes, hasLength(2));
      expect(e.serverCodes.first, 'visit_nest_foreign');
    });

    test('field names arrive the same way, and that is safe', () {
      // PocketBase's own validation fills `data` with the offending FIELD
      // names, which are keys too. Nothing distinguishes them structurally — a
      // caller resolves the codes it knows and ignores the rest, so a field
      // name finds no translation and falls through to the app's generic copy.
      // Which is the right outcome anyway: the form marks the fields itself.
      final e = from(400, {
        'data': {
          'name': {
            'code': 'validation_required',
            'message': 'Cannot be blank.',
          },
        },
        'message': 'Failed to create record.',
      });
      expect(e.serverCodes, ['name']);
    });

    test('no codes on the statuses that are not hook refusals', () {
      // An access-rule refusal is a 404 — PocketBase hides existence — so it
      // never carries codes, and neither does anything else.
      for (final status in [0, 401, 403, 404, 500, 502]) {
        expect(
          from(status, {
            'data': {'something': 1},
          }).serverCodes,
          isEmpty,
          reason: 'status $status',
        );
      }
      // 422 counts as validation alongside 400.
      expect(
        from(422, {
          'data': {'nest_protected': 1},
        }).serverCodes,
        ['nest_protected'],
      );
    });

    test('an absent or malformed data map yields no codes, never a throw', () {
      expect(from(400, const <String, dynamic>{}).serverCodes, isEmpty);
      expect(from(400, const {'data': null}).serverCodes, isEmpty);
      expect(from(400, const {'data': 'nonsense'}).serverCodes, isEmpty);
      expect(
        from(400, const {'data': <String, dynamic>{}}).serverCodes,
        isEmpty,
      );
    });

    test('the message is NOT used as copy, whatever it says', () {
      // A hook's message is an English developer line for the log, and the
      // server rewrites it anyway ("plain" comes back as "Plain."). Nothing
      // here exposes it as text for a user.
      final e = from(400, {
        'data': {'spot_pause_needs_reason': 1},
        'message': 'pause requires a reason',
      });
      expect(e.message, isNot(contains('pause requires a reason')));
    });
  });
}
