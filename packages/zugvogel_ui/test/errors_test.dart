@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:zugvogel_data/zugvogel_data.dart';
import 'package:zugvogel_ui/zugvogel_ui.dart';

import 'support/strings.dart';

/// An app whose hooks send codes: it implements the optional companion
/// interface and owns every sentence.
class _CodeStrings extends TestStrings implements ServerCodeStrings {
  const _CodeStrings();

  @override
  String? serverErrorFor(String code) => switch (code) {
    'spot_phase_needs_permitted' =>
      'Ein Spot wird erst aktiv, wenn die Erkundung bei „Erlaubt" steht.',
    'spot_pause_needs_reason' => 'Eine Pause braucht einen Grund.',
    _ => null,
  };
}

/// Whether a backend's own error copy reaches the user is a per-APP decision,
/// and these tests exist because getting it wrong is invisible: nothing asserts
/// the wording of a message that is not supposed to appear.
void main() {
  const strings = TestStrings();

  group('server codes', () {
    RepositoryException from(Map<String, dynamic> data) =>
        RepositoryException.fromClient(
          ClientException(
            statusCode: 400,
            response: {'data': data, 'message': 'a developer line'},
          ),
        );

    test('an app that does not implement the interface keeps its own copy', () {
      // federfall does not send codes, so nothing changes for it — and there is
      // no flag to get wrong.
      expect(
        errorMessage(strings, from({'spot_phase_needs_permitted': 1})),
        strings.errorValidation,
      );
    });

    test('an app that does gets its own sentence', () {
      expect(
        errorMessage(
          const _CodeStrings(),
          from({'spot_phase_needs_permitted': 1}),
        ),
        contains('Erlaubt'),
      );
    });

    test('an unknown code falls through to the generic copy', () {
      // `data` keys also carry PocketBase's field names. Skipping what it does
      // not recognise is what makes that harmless.
      const app = _CodeStrings();
      expect(
        errorMessage(app, from({'name': 1})),
        app.errorValidation,
      );
    });

    test('the first RECOGNISED code wins, not merely the first key', () {
      const app = _CodeStrings();
      expect(
        errorMessage(app, from({'name': 1, 'spot_pause_needs_reason': 1})),
        contains('Grund'),
      );
    });

    test('the developer message is never shown', () {
      // A hook's message is for the log. It is also rewritten by the server, so
      // it could not be copy even if somebody wanted it to be.
      const app = _CodeStrings();
      expect(
        errorMessage(app, from(const <String, dynamic>{})),
        app.errorValidation,
      );
    });

    test('a 404 is still a 404', () {
      const app = _CodeStrings();
      final notFound = RepositoryException.fromClient(
        ClientException(
          statusCode: 404,
          response: const {
            'data': {'spot_phase_needs_permitted': 1},
          },
        ),
      );
      expect(errorMessage(app, notFound), app.errorNotFound);
    });
  });
}
