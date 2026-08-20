import 'package:test/test.dart';
import 'package:zugvogel_core/zugvogel_core.dart';

void main() {
  group('Result.guard', () {
    test('captures a value as Ok', () async {
      final r = await Result.guard(() async => 7);
      expect(r.isOk, isTrue);
      expect(r.isErr, isFalse);
      expect(r.valueOrNull, 7);
    });

    test('captures a throw as Err, with the stack trace', () async {
      final r = await Result.guard<int>(() async => throw StateError('no'));
      expect(r.isErr, isTrue);
      expect(r.valueOrNull, isNull);
      expect(r, isA<Err<int>>());
      expect((r as Err<int>).error, isStateError);
      expect(r.stackTrace, isNotNull);
    });

    test('does not swallow the error type', () async {
      // The point of Result over a bare try/catch: the concrete error survives
      // for a caller that maps error types to user-facing copy.
      final r = await Result.guard<int>(
        () async => throw const FormatException('bad'),
      );
      expect((r as Err<int>).error, isA<FormatException>());
    });
  });

  group('fold', () {
    test('picks the ok branch', () {
      expect(
        const Result<int>.ok(2).fold(ok: (v) => 'v$v', err: (e) => 'e$e'),
        'v2',
      );
    });

    test('picks the err branch', () {
      expect(
        Result<int>.err(StateError('x')).fold(
          ok: (v) => 'v$v',
          err: (e) => 'err',
        ),
        'err',
      );
    });
  });

  test('equality is by value / error', () {
    expect(const Ok(1), const Ok(1));
    expect(const Ok(1), isNot(const Ok(2)));
    final e = StateError('x');
    expect(Err<int>(e), Err<int>(e));
  });
}
