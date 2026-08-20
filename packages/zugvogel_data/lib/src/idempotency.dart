import 'dart:math';

/// A random key for idempotent write routes (federfall-3ty3).
///
/// Generate ONE key per logical operation — when the user first presses submit
/// on a multi-record write — and reuse it for every retry of that operation:
/// the backend stores the response under the key and replays it instead of
/// writing twice. 128 bits of secure randomness as 32 hex chars — collisions
/// are not a practical concern, and the backend scopes keys per user anyway.
String newIdempotencyKey() {
  final rng = Random.secure();
  return List.generate(
    16,
    (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
