@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:zugvogel_data/zugvogel_data.dart';
import 'package:zugvogel_ui/zugvogel_ui.dart';

import 'support/strings.dart';

/// Whether a backend's own error copy reaches the user is a per-APP decision,
/// and these tests exist because getting it wrong is invisible: nothing asserts
/// the wording of a message that is not supposed to appear.
void main() {
  const strings = TestStrings();

  RepositoryException fromServer(int status, Map<String, dynamic> response) =>
      RepositoryException.fromClient(
        ClientException(statusCode: status, response: response),
      );

  RepositoryException hookRefusal() => fromServer(400, const {
    'data': <String, dynamic>{},
    'message':
        'Ein Spot wird erst aktiv, wenn die Erkundung bei '
        '"Zusage" steht.',
  });

  group('serverMessagesAreUserFacing', () {
    tearDown(() => serverMessagesAreUserFacing = false);

    test('off by default: the app keeps its own localized copy', () {
      // federfall's hooks say things like "audit_events is append-only." — in
      // English, addressed to a developer. Pushing that into a German UI would
      // be a regression, so the default has to be off and the opt-in explicit.
      expect(errorMessage(strings, hookRefusal()), strings.errorValidation);
    });

    test('on: the hook message wins, because only it knows why', () {
      // eiermann's hooks are written as copy. "Could not be saved" leaves the
      // user with no way forward; the sentence the hook wrote IS the way
      // forward.
      serverMessagesAreUserFacing = true;
      expect(errorMessage(strings, hookRefusal()), contains('Zusage'));
    });

    test('on, but per-field validation still uses the app copy', () {
      // A populated `data` is PocketBase's own field validation, whose message
      // is boilerplate ("Failed to create record."). The form marks the fields;
      // the summary belongs to the app.
      serverMessagesAreUserFacing = true;
      final fieldError = fromServer(400, const {
        'data': {
          'name': {
            'code': 'validation_required',
            'message': 'Cannot be blank.',
          },
        },
        'message': 'Failed to create record.',
      });
      expect(errorMessage(strings, fieldError), strings.errorValidation);
    });

    test('on, but a 404 keeps the localized copy', () {
      // An access-rule refusal arrives as 404 with "The requested resource
      // wasn't found." Opting in must not turn that into user-facing prose.
      serverMessagesAreUserFacing = true;
      final notFound = fromServer(404, const {
        'data': <String, dynamic>{},
        'message': "The requested resource wasn't found.",
      });
      expect(errorMessage(strings, notFound), strings.errorNotFound);
    });

    test('the other kinds are unaffected either way', () {
      for (final on in [false, true]) {
        serverMessagesAreUserFacing = on;
        expect(
          errorMessage(strings, fromServer(0, const {})),
          strings.errorOffline,
          reason: 'on=$on',
        );
        expect(
          errorMessage(strings, fromServer(401, const {})),
          strings.errorUnauthorized,
          reason: 'on=$on',
        );
        expect(
          errorMessage(strings, fromServer(500, const {})),
          strings.errorGenericTitle,
          reason: 'on=$on',
        );
      }
    });
  });
}
