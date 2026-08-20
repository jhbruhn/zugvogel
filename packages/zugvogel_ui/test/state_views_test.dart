import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:zugvogel_data/zugvogel_data.dart';
import 'package:zugvogel_ui/zugvogel_ui.dart';

import 'support/host.dart';
import 'support/strings.dart';

RepositoryException repoError(int status) =>
    RepositoryException.fromClient(ClientException(statusCode: status));

/// Set before a refresh to make the next load fail with this error.
Exception? _nextError;

final _dataProvider = FutureProvider<String>((ref) async {
  final error = _nextError;
  if (error != null) throw error;
  return 'loaded';
});

late void Function() _refresh;

/// An AsyncValueView over a provider the test can make fail on reload.
Widget refreshableView() => host(
  Consumer(
    builder: (context, ref, _) {
      _refresh = () => ref.invalidate(_dataProvider);
      return AsyncValueView<String>(
        value: ref.watch(_dataProvider),
        data: Text.new,
      );
    },
  ),
);

void main() {
  setUp(() => _nextError = null);

  group('LoadingView', () {
    testWidgets('shows the injected label by default', (tester) async {
      await tester.pumpWidget(host(const LoadingView()));
      expect(find.text('loadingLabel'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('an empty label hides the text but keeps the spinner', (
      tester,
    ) async {
      await tester.pumpWidget(host(const LoadingView(label: '')));
      expect(find.byType(Text), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('EmptyView', () {
    testWidgets('falls back to the injected generic message', (tester) async {
      await tester.pumpWidget(host(const EmptyView()));
      expect(find.text('emptyGeneric'), findsOneWidget);
    });

    testWidgets('the call-to-action needs BOTH a label and a handler', (
      tester,
    ) async {
      // An empty list doubles as the entry point for creating the first item,
      // so a half-configured action must not render a dead button.
      await tester.pumpWidget(host(const EmptyView(actionLabel: 'Add')));
      expect(find.text('Add'), findsNothing);

      var taps = 0;
      await tester.pumpWidget(
        host(EmptyView(actionLabel: 'Add', onAction: () => taps++)),
      );
      await tester.tap(find.text('Add'));
      expect(taps, 1);
    });
  });

  group('ErrorView', () {
    testWidgets('falls back to the injected generic title', (tester) async {
      await tester.pumpWidget(host(const ErrorView()));
      expect(find.text('errorGenericTitle'), findsOneWidget);
    });

    testWidgets('retry appears only when there is something to retry', (
      tester,
    ) async {
      await tester.pumpWidget(host(const ErrorView(message: 'boom')));
      expect(find.text('actionRetry'), findsNothing);

      var retries = 0;
      await tester.pumpWidget(
        host(ErrorView(message: 'boom', onRetry: () => retries++)),
      );
      await tester.tap(find.text('actionRetry'));
      expect(retries, 1);
    });
  });

  group('errorMessage', () {
    test('maps every repository kind to its own slot', () {
      const s = TestStrings();
      expect(errorMessage(s, repoError(0)), s.errorOffline);
      expect(errorMessage(s, repoError(401)), s.errorUnauthorized);
      expect(errorMessage(s, repoError(404)), s.errorNotFound);
      expect(errorMessage(s, repoError(422)), s.errorValidation);
      expect(errorMessage(s, repoError(500)), s.errorGenericTitle);
      expect(
        errorMessage(
          s,
          const RepositoryException(
            'x',
            kind: RepositoryErrorKind.unknownOutcome,
          ),
        ),
        s.errorUnknownOutcome,
      );
    });

    test('an unknown error type still gets a message', () {
      expect(
        errorMessage(const TestStrings(), StateError('x')),
        'errorGenericTitle',
      );
    });

    test('loadErrorMessage differs from errorMessage on the network case', () {
      // errorMessage's offline copy promises the user's entry is kept, which a
      // failed READ has no entry to keep.
      const s = TestStrings();
      expect(loadErrorMessage(s, repoError(0)), s.errorLoadFailed);
      expect(errorMessage(s, repoError(0)), s.errorOffline);
      // Everything else is phrased the same either way.
      expect(loadErrorMessage(s, repoError(404)), s.errorNotFound);
    });

    test('isNetworkError only fires on the network kind', () {
      expect(isNetworkError(repoError(0)), isTrue);
      expect(isNetworkError(repoError(404)), isFalse);
      expect(isNetworkError(StateError('x')), isFalse);
    });
  });

  group('AsyncValueView', () {
    Widget view(AsyncValue<String> value, {VoidCallback? onRetry}) => host(
      AsyncValueView<String>(
        value: value,
        data: Text.new,
        onRetry: onRetry,
      ),
    );

    testWidgets('renders data, loading and error states', (tester) async {
      await tester.pumpWidget(view(const AsyncValue.data('loaded')));
      expect(find.text('loaded'), findsOneWidget);

      await tester.pumpWidget(view(const AsyncValue.loading()));
      expect(find.byType(LoadingView), findsOneWidget);

      await tester.pumpWidget(
        view(AsyncValue.error(repoError(404), StackTrace.empty)),
      );
      expect(find.text('errorNotFound'), findsOneWidget);
    });

    testWidgets('a dropped connection KEEPS data already on screen', (
      tester,
    ) async {
      // The whole point (federfall-gmnc): replacing a populated list with a
      // full-screen error costs the user their scroll position and filters for
      // a condition they can only wait out — and the offline strip already
      // states the cause app-wide.
      //
      // Driven through a real provider refresh rather than by hand-building an
      // AsyncValue: the has-value-AND-has-error state only exists because
      // riverpod carries the previous value across a failed reload, so
      // constructing it directly would be testing the test.
      await tester.pumpWidget(refreshableView());
      await tester.pump();
      expect(find.text('loaded'), findsOneWidget);

      _nextError = repoError(0);
      _refresh();
      // Settle, not a single pump: the reload is async, so one frame later the
      // provider is still loading and the data would still be on screen for
      // the wrong reason.
      await tester.pumpAndSettle();

      expect(find.text('loaded'), findsOneWidget);
      expect(find.byType(ErrorView), findsNothing);
    });

    testWidgets('any OTHER failure still replaces the stale data', (
      tester,
    ) async {
      // Quietly serving stale data after a permission or validation error
      // would be dishonest.
      await tester.pumpWidget(refreshableView());
      await tester.pump();
      expect(find.text('loaded'), findsOneWidget);

      _nextError = repoError(403);
      _refresh();
      await tester.pumpAndSettle();

      expect(find.text('errorUnauthorized'), findsOneWidget);
      expect(find.text('loaded'), findsNothing);
    });

    testWidgets('a custom errorMessage wins over the shared mapping', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AsyncValueView<String>(
            value: AsyncValue.error(repoError(404), StackTrace.empty),
            data: Text.new,
            errorMessage: (_) => 'bespoke',
          ),
        ),
      );
      expect(find.text('bespoke'), findsOneWidget);
    });
  });
}
