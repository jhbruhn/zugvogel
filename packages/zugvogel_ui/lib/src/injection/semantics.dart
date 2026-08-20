import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The colours a shared widget needs that Material's [ColorScheme] has no name
/// for.
///
/// **Injection boundary 2.** No widget in this package names a colour. Ordinary
/// surfaces, text and accents come from `Theme.of(context).colorScheme`; the
/// three *meanings* Material does not model — this is good, this needs
/// attention, this is wrong — plus a categorical series palette for charts,
/// come from here. Federfall's palette and eiermann's stay independent.
///
/// Registered as a [ThemeExtension] so it follows brightness like everything
/// else in the theme:
///
/// ```dart
/// ThemeData(
///   colorScheme: scheme,
///   extensions: [ZugvogelSemantics.fromScheme(scheme)],
/// )
/// ```
@immutable
class ZugvogelSemantics extends ThemeExtension<ZugvogelSemantics> {
  const ZugvogelSemantics({
    required this.good,
    required this.onGood,
    required this.warning,
    required this.onWarning,
    required this.critical,
    required this.onCritical,
    required this.categorical,
  });

  /// A serviceable default derived entirely from [scheme].
  ///
  /// Contains no colour of its own — that is the point — so an app gets a
  /// palette that already matches its seed, and only writes the constructor
  /// out by hand when it wants specific hues.
  ///
  /// `critical` maps to the scheme's error role, which is what Material
  /// already reserves for it. `good` and `warning` borrow tertiary and
  /// secondary: not because those *mean* anything of the sort, but because
  /// they are the two roles a seeded scheme leaves free, and a wrong-looking
  /// green is a smaller problem than a green that clashes with the brand.
  factory ZugvogelSemantics.fromScheme(ColorScheme scheme) => ZugvogelSemantics(
    good: scheme.tertiary,
    onGood: scheme.onTertiary,
    warning: scheme.secondary,
    onWarning: scheme.onSecondary,
    critical: scheme.error,
    onCritical: scheme.onError,
    categorical: [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.error,
      scheme.primaryContainer,
      scheme.tertiaryContainer,
      scheme.secondaryContainer,
      scheme.errorContainer,
    ],
  );

  /// Resolved, healthy, done.
  final Color good;
  final Color onGood;

  /// Due soon, needs a look, degraded but working.
  final Color warning;
  final Color onWarning;

  /// Overdue, failed, destructive.
  final Color critical;
  final Color onCritical;

  /// Series colours for charts, in order.
  ///
  /// A categorical palette cannot be derived from a single role — adjacent
  /// slices have to be told apart — so it is injected rather than computed at
  /// the call site. Charts index into it modulo its length and must not assume
  /// a count.
  final List<Color> categorical;

  /// The semantics for this subtree, or a scheme-derived default when the app
  /// registered no extension.
  ///
  /// Falls back rather than throwing: an unstyled-but-legible chart is a far
  /// better outcome in production than a crash, and the fallback is derived
  /// from the app's own scheme, so it is never off-brand — only unspecific.
  // A lookup, not a constructor: it resolves an already-built extension out of
  // the theme, and only falls back to building one.
  // ignore: prefer_constructors_over_static_methods
  static ZugvogelSemantics of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ZugvogelSemantics>() ??
        ZugvogelSemantics.fromScheme(theme.colorScheme);
  }

  /// The [categorical] entry for series [index], wrapping around.
  Color series(int index) => categorical[index.abs() % categorical.length];

  @override
  ZugvogelSemantics copyWith({
    Color? good,
    Color? onGood,
    Color? warning,
    Color? onWarning,
    Color? critical,
    Color? onCritical,
    List<Color>? categorical,
  }) => ZugvogelSemantics(
    good: good ?? this.good,
    onGood: onGood ?? this.onGood,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    critical: critical ?? this.critical,
    onCritical: onCritical ?? this.onCritical,
    categorical: categorical ?? this.categorical,
  );

  @override
  ZugvogelSemantics lerp(ZugvogelSemantics? other, double t) {
    if (other == null) return this;
    return ZugvogelSemantics(
      good: Color.lerp(good, other.good, t)!,
      onGood: Color.lerp(onGood, other.onGood, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
      onCritical: Color.lerp(onCritical, other.onCritical, t)!,
      // Lerping two palettes of different lengths has no meaning, so the
      // longer one wins its tail rather than being truncated mid-animation.
      categorical: [
        for (var i = 0; i < categorical.length; i++)
          if (i < other.categorical.length)
            Color.lerp(categorical[i], other.categorical[i], t)!
          else
            categorical[i],
        ...other.categorical.skip(categorical.length),
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ZugvogelSemantics &&
      other.good == good &&
      other.onGood == onGood &&
      other.warning == warning &&
      other.onWarning == onWarning &&
      other.critical == critical &&
      other.onCritical == onCritical &&
      listEquals(other.categorical, categorical);

  @override
  int get hashCode => Object.hash(
    good,
    onGood,
    warning,
    onWarning,
    critical,
    onCritical,
    Object.hashAll(categorical),
  );
}

/// `context.zvColors.critical`, alongside `context.zv` for text.
extension ZugvogelSemanticsContext on BuildContext {
  /// The shared widgets' semantic colours for this subtree.
  ZugvogelSemantics get zvColors => ZugvogelSemantics.of(this);
}
