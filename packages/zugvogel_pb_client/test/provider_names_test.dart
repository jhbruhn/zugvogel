@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every provider this package exposes carries a debug `name`.
///
/// This is the one thing hand-writing providers loses against
/// `riverpod_generator`, which sets `name: r'fooProvider'` for you. It matters
/// because `LoggingProviderObserver` — extracted precisely so a provider
/// failure is visible app-wide — logs `context.provider.name ?? runtimeType`.
/// Without a name the log line reads `FutureProvider<String>`, and this
/// package has TWO of those (userAgent and appVersion), so the message is
/// ambiguous exactly when somebody is reading it to find out what broke.
///
/// A source sweep rather than a runtime check: reading a name off a provider
/// requires building it, and half of these need a live server or a platform
/// channel. The declaration is what is being asserted anyway.
void main() {
  test('every provider declares a debug name', () {
    final missing = <String>[];
    final declaration = RegExp(
      r'^final (?:[A-Za-z_][\w<>?, ]*\s+)?([a-z][A-Za-z0-9]*Provider)\s*=',
      multiLine: true,
    );

    for (final file
        in Directory('lib/src')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final match in declaration.allMatches(source)) {
        final name = match.group(1)!;
        // The name has to appear after the declaration starts — anywhere in the
        // constructor call, since the argument's position varies with how the
        // formatter broke the line.
        final tail = source.substring(match.start);
        if (!tail.contains("name: '$name'")) {
          missing.add('${file.path}: $name');
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'A provider with no name logs as its TYPE when it fails, and several '
          'providers here share a type. Pass name: to the constructor:\n'
          '${missing.join('\n')}',
    );
  });

  test('the sweep finds the providers at all', () {
    // A guard that silently scans nothing is worse than no guard: this package
    // has 18 providers, so a regex that stopped matching would otherwise pass.
    final declaration = RegExp(
      r'^final (?:[A-Za-z_][\w<>?, ]*\s+)?([a-z][A-Za-z0-9]*Provider)\s*=',
      multiLine: true,
    );
    var found = 0;
    for (final file
        in Directory('lib/src')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      found += declaration.allMatches(file.readAsStringSync()).length;
    }
    expect(found, greaterThanOrEqualTo(18));
  });
}
