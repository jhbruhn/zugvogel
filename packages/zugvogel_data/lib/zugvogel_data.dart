/// Generic PocketBase repository layer.
///
/// Two rules this package exists to enforce:
///
/// 1. A filter is built, never concatenated. `PbFilter` has no public
///    constructor, so interpolating user input into a filter string is a
///    compile error rather than a latent injection hole.
/// 2. A list is paged by keyset, not by offset. An append-only feed grows at
///    the end being read from, and `?page=2` over a moving window skips rows.
///
/// Domain-free: the repositories an app writes on top of this carry the
/// collection names and the mappers.
library;

export 'src/idempotency.dart';
export 'src/pb_repository.dart';
export 'src/repository_exception.dart';
