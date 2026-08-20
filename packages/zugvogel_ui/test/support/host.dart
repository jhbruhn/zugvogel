import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zugvogel_ui/zugvogel_ui.dart';

import 'strings.dart';

/// Wraps [child] in the minimum an extracted widget needs: Material, real
/// localizations for the platform widgets, and the injected strings.
///
/// No `overrides` parameter: riverpod does not export the `Override` type, so
/// it cannot be named in a signature. A test that needs one builds its own
/// ProviderScope around [host]'s result instead — see the offline-notice test.
Widget host(
  Widget child, {
  ZugvogelStrings strings = const TestStrings(),
  ThemeData? theme,
}) => ProviderScope(
  child: MaterialApp(
    theme: theme,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('en'), Locale('de')],
    home: ZugvogelStringsScope(
      strings: strings,
      child: Scaffold(body: child),
    ),
  ),
);
