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

  group('serverMessage — a message the server wrote to be READ', () {
    RepositoryException from(int status, Map<String, dynamic> response) =>
        RepositoryException.fromClient(
          ClientException(statusCode: status, response: response),
        );

    test('a hook refusal (400, empty data, prose) comes through', () {
      // The shape a `throw new BadRequestError("…")` in a PocketBase hook
      // produces. It is the only party that knows why the write was refused,
      // so dropping it leaves the user with "could not be saved" and no way
      // forward.
      final e = from(400, {
        'data': <String, dynamic>{},
        'message':
            'Ein Spot wird erst aktiv, wenn die Erkundung bei '
            '"Zusage" steht.',
        'status': 400,
      });
      expect(e.kind, RepositoryErrorKind.validation);
      expect(e.serverMessage, contains('Zusage'));
    });

    test('per-field validation does NOT (data is populated)', () {
      // PocketBase's own field validation. `message` is English boilerplate
      // ("Failed to create record.") and the form shows the field errors, so
      // the app's localized summary belongs at the top instead.
      final e = from(400, {
        'data': {
          'name': {
            'code': 'validation_required',
            'message': 'Cannot be blank.',
          },
        },
        'message': 'Failed to create record.',
        'status': 400,
      });
      expect(e.kind, RepositoryErrorKind.validation);
      expect(
        e.serverMessage,
        isNull,
        reason:
            'showing "Failed to create record." would be a regression on '
            'the localized copy it replaced',
      );
    });

    test('an access-rule refusal cannot leak — it arrives as 404', () {
      // PocketBase hides existence deliberately, so a rule refusal is a 404
      // with "The requested resource wasn't found." It must never reach the UI
      // as prose; classifying by kind is what prevents it.
      final e = from(404, {
        'data': <String, dynamic>{},
        'message': "The requested resource wasn't found.",
        'status': 404,
      });
      expect(e.kind, RepositoryErrorKind.notFound);
      expect(e.serverMessage, isNull);
    });

    test('no other status contributes a message, however tempting', () {
      for (final status in [0, 401, 403, 404, 500, 502]) {
        expect(
          from(status, {
            'data': <String, dynamic>{},
            'message': 'Something in English from the server',
          }).serverMessage,
          isNull,
          reason: 'status $status',
        );
      }
      // 422 counts as validation alongside 400.
      expect(
        from(422, {
          'data': <String, dynamic>{},
          'message': 'Nicht erlaubt',
        }).serverMessage,
        'Nicht erlaubt',
      );
    });

    test('an empty or missing message is not a message', () {
      expect(from(400, {'message': ''}).serverMessage, isNull);
      expect(from(400, {'message': '   '}).serverMessage, isNull);
      expect(from(400, <String, dynamic>{}).serverMessage, isNull);
      expect(from(400, {'message': 42}).serverMessage, isNull);
    });
  });
}
