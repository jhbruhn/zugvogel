/// Domain-free primitives shared by the Zugvogel apps.
///
/// Nothing in this package may know a product's vocabulary, palette or
/// configuration — see the three injection boundaries in CLAUDE.md. Pure Dart:
/// no Flutter, and no code generation.
library;

export 'src/converters.dart';
export 'src/geo_point.dart';
export 'src/logging/app_logger.dart';
export 'src/parallel_wait.dart';
export 'src/result.dart';
export 'src/wire_enum.dart';
