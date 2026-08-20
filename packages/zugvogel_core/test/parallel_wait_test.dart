import 'dart:async';

import 'package:test/test.dart';
import 'package:zugvogel_core/zugvogel_core.dart';

class _Offline implements Exception {
  const _Offline();
}

void main() {
  group('waitUnwrapped', () {
    test('returns both results in order', () async {
      final r = await (Future.value(1), Future.value('a')).waitUnwrapped;
      expect(r, (1, 'a'));
    });

    test(
      'throws the FIRST failure as itself, not a ParallelWaitError',
      () async {
        // The whole reason this extension exists. Record `.wait` wraps any
        // failure in a ParallelWaitError, and error mapping that switches
        // on the concrete type then falls through to "something went wrong"
        // — taking the content already on screen with it.
        await expectLater(
          (
            Future<int>.error(const _Offline()),
            Future.value('a'),
          ).waitUnwrapped,
          throwsA(isA<_Offline>()),
        );
      },
    );

    test('for comparison: dart:async .wait really does wrap it', () async {
      await expectLater(
        (Future<int>.error(const _Offline()), Future.value('a')).wait,
        throwsA(isA<ParallelWaitError<dynamic, dynamic>>()),
      );
    });

    test(
      'observes every future, so a second failure is not unhandled',
      () async {
        // If the losing future's error were left unobserved it would surface
        // later as an unhandled async error and fail the test run.
        await expectLater(
          (
            Future<int>.error(const _Offline()),
            Future<String>.error(StateError('second')),
          ).waitUnwrapped,
          throwsA(anything),
        );
        // Give any unhandled-error report a turn of the event loop to appear.
        await Future<void>.delayed(Duration.zero);
      },
    );

    test('works for three, four, five and seven futures', () async {
      expect(
        await (Future.value(1), Future.value(2), Future.value(3)).waitUnwrapped,
        (1, 2, 3),
      );
      expect(
        await (
          Future.value(1),
          Future.value(2),
          Future.value(3),
          Future.value(4),
        ).waitUnwrapped,
        (1, 2, 3, 4),
      );
      expect(
        await (
          Future.value(1),
          Future.value(2),
          Future.value(3),
          Future.value(4),
          Future.value(5),
        ).waitUnwrapped,
        (1, 2, 3, 4, 5),
      );
      expect(
        await (
          Future.value(1),
          Future.value(2),
          Future.value(3),
          Future.value(4),
          Future.value(5),
          Future.value(6),
          Future.value(7),
        ).waitUnwrapped,
        (1, 2, 3, 4, 5, 6, 7),
      );
    });
  });
}
