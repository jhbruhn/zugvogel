import 'package:test/test.dart';
import 'package:zugvogel_data/zugvogel_data.dart';

void main() {
  group('newIdempotencyKey', () {
    test('is 32 lowercase hex chars — 128 bits', () {
      final key = newIdempotencyKey();
      expect(key, hasLength(32));
      expect(key, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('every byte is padded, so the key never comes out short', () {
      // The bug this pins: toRadixString(16) on a byte below 16 yields one
      // char, so without the padLeft a key with leading-zero bytes would be
      // shorter than 32 and two different values could collapse to the same
      // string.
      final keys = List.generate(500, (_) => newIdempotencyKey());
      expect(keys.every((k) => k.length == 32), isTrue);
    });

    test('keys are distinct — the whole point is one per operation', () {
      final keys = List.generate(1000, (_) => newIdempotencyKey()).toSet();
      expect(keys, hasLength(1000));
    });
  });
}
