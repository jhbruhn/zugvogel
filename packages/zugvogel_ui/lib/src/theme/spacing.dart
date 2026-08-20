/// The spacing scale, in logical pixels.
///
/// A small fixed scale keeps layouts consistent and stops magic numbers
/// spreading through widgets. It is a scale, not a palette — no product
/// identity lives in a gap width — so it is shared rather than injected.
abstract final class ZugvogelSpacing {
  /// 4 — hairline gaps between tightly related elements.
  static const double xs = 4;

  /// 8 — default gap inside a row/column of related controls.
  static const double sm = 8;

  /// 16 — standard padding around content and between sections.
  static const double md = 16;

  /// 24 — generous separation between distinct groups.
  static const double lg = 24;

  /// 32 — page-level breathing room.
  static const double xl = 32;
}
