@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The three injection boundaries, enforced by sweeping the source tree.
///
/// These are not style rules. A wide shared UI package that knows one
/// product's vocabulary, palette or environment welds two product designs
/// together, and the welding happens one innocuous line at a time — a label
/// here, a hex colour there. A review catches the obvious ones; this catches
/// the rest, on every commit, across all four packages.
///
/// The test reads the repo from disk, so it only runs on the VM.
void main() {
  final packages = _packageLibDirs();

  test('the sweep actually found the packages', () {
    // A guard test that silently scans nothing is worse than no guard at all.
    expect(packages, hasLength(4));
    for (final dir in packages) {
      expect(_dartFiles(dir), isNotEmpty, reason: dir.path);
    }
  });

  group('boundary 1 — no strings', () {
    test('no package imports an app l10n class', () {
      // The apps' generated localizations. Importing one would make the
      // package depend on an app, which is backwards.
      final offenders = _matches(
        packages,
        RegExp(
          r'''import\s+'package:(federfall|eiermann)[^']*'|app_localizations''',
        ),
      );
      expect(offenders, isEmpty, reason: _explain(offenders));
    });

    test('no German user-facing word is hardcoded', () {
      // A spot-check on the words that actually appeared in the widgets this
      // library was extracted from. Not a spell-checker — a canary: if
      // "Abbrechen" is back in a shared widget, so is the whole problem.
      final offenders = _matches(
        packages,
        RegExp(
          r"'[^']*\b(Abbrechen|Speichern|Verwerfen|Löschen|Fehler|"
          r"Wird geladen|Erneut versuchen|Offline)\b[^']*'",
        ),
      );
      expect(offenders, isEmpty, reason: _explain(offenders));
    });
  });

  group('boundary 2 — no colours', () {
    test('no hex colour literal anywhere in the library', () {
      // A hex literal is a palette, and a palette is a brand. Colours come
      // from Theme.of(context).colorScheme, or from ZugvogelSemantics for the
      // meanings Material does not name.
      //
      // Colors.black / Colors.white are deliberately NOT covered by this rule:
      // the surround of a full-screen photo viewer is not brand, it is the
      // neutral chrome every photo viewer has.
      final offenders = _matches(packages, RegExp(r'Color\(0x'));
      expect(offenders, isEmpty, reason: _explain(offenders));
    });

    test('no seeded scheme or brand seed is defined here', () {
      // Building the theme is the app's job; this library only reads it.
      final offenders = _matches(
        packages,
        RegExp(r'ColorScheme\.fromSeed|MaterialColor\('),
      );
      expect(offenders, isEmpty, reason: _explain(offenders));
    });
  });

  group('boundary 3 — no configuration', () {
    test('nothing reads a compile-time define', () {
      // The environment is the app's. Whatever the library needs is passed in
      // — see PbClientConfig.
      final offenders = _matches(
        packages,
        RegExp(r'\.fromEnvironment|AppEnvironment|AppFlavor'),
      );
      expect(offenders, isEmpty, reason: _explain(offenders));
    });

    test('no service name, route or storage key is hardcoded', () {
      // Every one of these derives from PbClientConfig.service. A hardcoded
      // one would point eiermann at federfall's /info route, or store one
      // app's bearer token under the other's key.
      final offenders = _matches(
        packages,
        RegExp(r'''/api/(federfall|eiermann)|'(federfall|eiermann)\.'''),
      );
      expect(offenders, isEmpty, reason: _explain(offenders));
    });
  });
}

/// `packages/*/lib` for every workspace member.
List<Directory> _packageLibDirs() {
  // The test runs with the package as cwd; the workspace root is two up.
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !File('${dir.path}/pubspec.yaml').readAsStringSync().contains(
        'zugvogel_workspace',
      )) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('Could not find the zugvogel workspace root from ${dir.path}');
    }
    dir = parent;
  }
  return Directory('${dir.path}/packages')
      .listSync()
      .whereType<Directory>()
      .map((d) => Directory('${d.path}/lib'))
      .where((d) => d.existsSync())
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

List<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// Every `file:line` in [dirs] matching [pattern], ignoring comments — the
/// rules are about code, and the reasons they exist are written in prose that
/// naturally quotes what it forbids.
List<String> _matches(List<Directory> dirs, RegExp pattern) {
  final hits = <String>[];
  for (final dir in dirs) {
    for (final file in _dartFiles(dir)) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final code = line.trimLeft();
        if (code.startsWith('//') || code.startsWith('///')) continue;
        if (pattern.hasMatch(line)) {
          hits.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
  }
  return hits;
}

String _explain(List<String> offenders) =>
    'Injection boundary violated in:\n${offenders.join('\n')}';
