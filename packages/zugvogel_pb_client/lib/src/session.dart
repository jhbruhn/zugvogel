import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zugvogel_core/zugvogel_core.dart';
import 'package:zugvogel_pb_client/src/server_config.dart';
import 'package:zugvogel_pb_client/src/server_config_controller.dart';

/// The slice of an app's auth repository that session upkeep needs.
///
/// The repository itself is domain — it maps a PocketBase record to *this*
/// app's user model — so it stays in the app. This is the seam: the app
/// overrides [pbSessionProvider] with an adapter over its own repository, and
/// [sessionRefreshProvider] works against nothing but these three members.
abstract interface class PbSession {
  /// Emits whenever the session changes (login, logout, refresh).
  Stream<void> get changes;

  /// Re-issues the token with a fresh `exp`.
  ///
  /// Must be a no-op when signed out, and must clear the auth store only on a
  /// 401/403 — a genuinely dead or revoked token. Any other failure (offline,
  /// server down) has to leave the session alone.
  Future<void> refresh();
}

/// The app's session adapter. **The app must override this** if it uses
/// [sessionRefreshProvider].
final pbSessionProvider = FutureProvider<PbSession>(
  (ref) => throw UnimplementedError(
    "pbSessionProvider must be overridden with an adapter over the app's "
    'auth repository. See PbSession.',
  ),
);

/// How often to proactively roll the session token while the app stays open.
///
/// A PocketBase auth token typically lives 30 days; refreshing far more often
/// than that keeps a continuously-used session alive indefinitely without
/// being chatty. Foregrounded desktop/web sessions rely on this — they never
/// fire [AppLifecycleListener.onResume]; on mobile, resume already covers the
/// common background-then-return case.
const sessionHeartbeat = Duration(hours: 6);

/// Silently rolls the PocketBase session token so active users are not logged
/// out when it expires.
///
/// PocketBase issues its own JWT (for OIDC/OAuth2 logins too — the provider's
/// tokens are not used to extend the session) and the client stores it with a
/// fixed `exp`. Without this the token simply lapses after its duration and
/// the router gate bounces the user to the login screen. Here [PbSession
/// .refresh] runs once at startup, whenever the app resumes from background,
/// and on a slow heartbeat, so every active use rolls the window forward.
///
/// A refresh that fails is swallowed: a transient network blip must never log
/// the user out. See [PbSession.refresh] for the contract that makes that
/// safe.
///
/// Kept alive; an app activates it by listening from its router at startup.
final sessionRefreshProvider = FutureProvider<void>((ref) async {
  // Until a server is configured there is no client to refresh against — and
  // resolving the session would force PocketBase to initialise without a URL
  // and fault. Bail out now; this rebuilds once setup completes.
  final config = await ref.watch(serverConfigControllerProvider.future);
  if (config is! ServerConfigured) return;

  final session = await ref.watch(pbSessionProvider.future);

  Future<void> refresh() async {
    try {
      await session.refresh();
    } on Object catch (error, stackTrace) {
      // Offline / server down / any non-401-403 failure: leave the session
      // untouched. refresh() itself clears the store on a genuinely dead
      // token. Reported rather than silent so a systematically failing refresh
      // is visible in a log.
      reportCaughtError(error, stackTrace, context: 'Session refresh failed');
    }
  }

  final lifecycle = AppLifecycleListener(onResume: () => unawaited(refresh()));
  final heartbeat = Timer.periodic(
    sessionHeartbeat,
    (_) => unawaited(refresh()),
  );
  void teardown() {
    lifecycle.dispose();
    heartbeat.cancel();
  }

  // Disposed during the await above? Registering onDispose would throw, so
  // tear down inline instead.
  if (!ref.mounted) {
    teardown();
    return;
  }
  ref.onDispose(teardown);

  // Roll the window (and validate against the server) once at startup.
  unawaited(refresh());
});

/// Best-effort, fire-and-forget purge of something device-local, for sign-out
/// and server switching.
///
/// A storage error (or a hung store) must never block signing out, so the
/// purge runs unawaited and failures are only logged. A locked keystore is not
/// allowed to be what stops someone signing out.
///
/// What each app purges is domain — a protected-file image cache, an
/// unfinished draft holding a third party's contact details — but the contract
/// is not: on sign-out, device-local copies of this user's data go, because a
/// cache hit is served without any token check and would otherwise show the
/// next user of this device the previous one's data.
void purgeOnSignOut(Future<void> Function() action, String failureContext) {
  unawaited(
    Future(action).catchError((Object error, StackTrace stackTrace) {
      reportCaughtError(error, stackTrace, context: failureContext);
    }),
  );
}
