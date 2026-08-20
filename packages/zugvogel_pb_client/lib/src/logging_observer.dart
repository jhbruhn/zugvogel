import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zugvogel_core/zugvogel_core.dart';

/// Logs every provider failure through [AppLogger], giving app-wide visibility
/// into async errors (failed loads, thrown notifiers) without each provider
/// having to log for itself.
///
/// Lives in this package rather than in `zugvogel_core` because it is riverpod
/// plumbing, and this is where Zugvogel's shared riverpod plumbing lives —
/// core stays pure Dart with no Flutter dependency.
final class LoggingProviderObserver extends ProviderObserver {
  const LoggingProviderObserver(this._logger);

  final AppLogger _logger;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final name = context.provider.name ?? context.provider.runtimeType;
    _logger.error(
      'Provider failed: $name',
      error: error,
      stackTrace: stackTrace,
      name: 'riverpod',
    );
  }
}
