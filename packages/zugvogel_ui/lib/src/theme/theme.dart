import 'package:flutter/material.dart';
import 'package:zugvogel_ui/src/injection/semantics.dart';

/// The Material 3 theme scaffold both Zugvogel apps build on.
///
/// It supplies the parts that are *not* brand — the bundled font stack, the
/// component shapes and densities the shared widgets are drawn against, and a
/// registered [ZugvogelSemantics] — and takes the one part that is: the seed
/// colour.
/// Each app passes its own seed colour and gets a palette of its own
/// (injection boundary 2).
abstract final class ZugvogelTheme {
  /// Families consulted for glyphs the bundled Roboto lacks (federfall-sbtx).
  ///
  /// Web has no system fonts: CanvasKit/skwasm resolves a missing codepoint by
  /// downloading a per-glyph Noto slice from fonts.gstatic.com — blocked by the
  /// app's CSP and retried on every layout, so a single `✓` in a note produced
  /// an endless stream of console errors on a deployed instance. Declaring the
  /// fonts in a pubspec is not enough: the engine tests coverage against the
  /// families a `TextStyle` names, so they have to be named here too.
  ///
  /// Order is text-presentation first — a pictograph that exists in Noto Sans
  /// Symbols 2 (`✓ ✗ ★ ⚠ ♥`, and outlines of the older emoji) renders
  /// monochrome, which reads better inside a record than a coloured sign;
  /// anything emoji-only (`😀 🥚 ✅`) still comes out in colour. Swapping the
  /// last two entries flips that preference.
  ///
  /// Not exhaustive by choice: CJK, Arabic and Indic scripts would add ~12 MB,
  /// so those still fall back to a download the CSP blocks — boxes on web,
  /// which is the honest outcome for a German-language app.
  ///
  /// Every name carries the `packages/zugvogel_ui/` prefix because the assets
  /// ship in this package: that prefix is how the engine resolves a
  /// package-provided family, and without it the families silently do not
  /// exist — which looks exactly like not having bundled them at all.
  static const List<String> fontFallbacks = <String>[
    'packages/zugvogel_ui/Noto Sans Symbols', // → ↑ ↓ ♀ ♂ ⌀ ⚕
    'packages/zugvogel_ui/Noto Sans Symbols 2', // ✓ ✗ ☑ ★ ♥ ⚠
    'packages/zugvogel_ui/Noto Color Emoji', // everything else, in COLRv1
  ];

  /// The bundled base family.
  static const String fontFamily = 'packages/zugvogel_ui/Roboto';

  /// The asset paths [fontFallbacks] and [fontFamily] resolve to, for the test
  /// that pins both halves.
  static const List<String> fontAssets = <String>[
    'assets/fonts/Roboto-Regular.ttf',
    'assets/fonts/Roboto-Italic.ttf',
    'assets/fonts/Roboto-Medium.ttf',
    'assets/fonts/Roboto-Bold.ttf',
    'assets/fonts/NotoSansSymbols-Regular.ttf',
    'assets/fonts/NotoSansSymbols2-Regular.ttf',
    'assets/fonts/NotoColorEmoji.ttf',
  ];

  /// A theme seeded from [seed] for [brightness].
  ///
  /// Pass [semantics] to override the scheme-derived good/warning/critical and
  /// categorical palette; omit it for one derived from the seeded scheme.
  static ThemeData build({
    required Color seed,
    required Brightness brightness,
    ZugvogelSemantics? semantics,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return fromScheme(colorScheme, semantics: semantics);
  }

  /// A theme over an existing [colorScheme] — for an app that builds its
  /// scheme some other way (a full custom palette, a dynamic system colour).
  static ThemeData fromScheme(
    ColorScheme colorScheme, {
    ZugvogelSemantics? semantics,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // Named explicitly (rather than relying on the M3 default) so the
      // fallbacks below hang off the same family this package actually
      // bundles.
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallbacks,
      extensions: [semantics ?? ZugvogelSemantics.fromScheme(colorScheme)],
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        scrolledUnderElevation: 2,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      // Filled rather than outlined: a subtle tonal surface that stays present
      // on busy scroll views without the fussiness of a hairline border. One
      // change lifts every card at once.
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      // A selected ListTile (the active row in a list-detail pane) gets a
      // visible primary tint behind it — but the text/icons stay onSurface
      // rather than M3's default primary recolouring, which reads as poor
      // contrast on the tint. The background alone marks the open row.
      listTileTheme: ListTileThemeData(
        selectedColor: colorScheme.onSurface,
        selectedTileColor: colorScheme.primary.withValues(alpha: 0.10),
      ),
    );
  }
}
