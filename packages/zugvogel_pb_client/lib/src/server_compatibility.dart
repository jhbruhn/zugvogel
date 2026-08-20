import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zugvogel_pb_client/src/server_info.dart';
import 'package:zugvogel_pb_client/src/server_info_provider.dart';
import 'package:zugvogel_pb_client/src/user_agent_client.dart';

/// Whether the running app can talk to the configured server (federfall-1wm).
///
/// Each Zugvogel app ships its own app and backend from one repo under a
/// single release-please version, so the major component is the app↔server
/// wire contract: any change
/// that breaks it is a `!`/BREAKING CHANGE commit, which bumps the major. Two
/// builds therefore interoperate exactly when their majors match — the minor
/// and patch are free to differ in either direction.
///
/// The skew this guards is a *deployment* one, not a development one: an
/// operator's container and a user's installed APK update independently (and
/// an unattended APK updater makes the app the newer of the two more often
/// than not).
enum ServerCompatibility {
  /// Majors match, and the app is at or above the server's `minClient` floor.
  compatible,

  /// The app is older than the server — the user must update the app.
  clientTooOld,

  /// The app is newer than the server — the *operator* must update the
  /// backend. Telling this user to update their app would be a dead end.
  serverTooOld,
}

/// Version reported when the running build has no real version baked in: a
/// backend image built without its version build-arg falls back to `0.0.0-dev`
/// (so `/info` reports `0.0`), and [appVersionProvider] falls back to `0.0.0`
/// when `PackageInfo` cannot resolve one.
///
/// No release carries it, so it is safe to read as "unversioned build".
const _devVersion = '0.0';

/// Decides whether [appVersion] and the backend described by [info] can talk.
///
/// Deliberately fails **open**: a null [info] (discovery failed), an
/// unversioned dev build on either side, or a version string that won't parse
/// all yield [ServerCompatibility.compatible]. A false positive locks the user
/// out of the app entirely, which is far worse than letting a genuinely
/// incompatible pair through to a clearer runtime error.
ServerCompatibility checkServerCompatibility({
  required String appVersion,
  required ServerInfo? info,
}) {
  if (info == null) return ServerCompatibility.compatible;

  final appMajor = _majorOf(appVersion);
  final serverMajor = _majorOf(info.version);
  if (appMajor == null || serverMajor == null) {
    return ServerCompatibility.compatible;
  }
  // An unversioned build on either side can't be judged — local stacks run a
  // dev image against a released app and vice versa.
  if (_isDev(appVersion) || _isDev(info.version)) {
    return ServerCompatibility.compatible;
  }

  if (appMajor < serverMajor) return ServerCompatibility.clientTooOld;
  if (appMajor > serverMajor) return ServerCompatibility.serverTooOld;

  // Same major, so the wire contract holds. `minClient` is the backend's
  // optional finer floor on top of that — an operator raising it says "this
  // release needs at least that client", e.g. after a fix clients must have.
  final floor = info.minClient;
  if (floor != null && !_isDev(floor) && _compare(appVersion, floor) < 0) {
    return ServerCompatibility.clientTooOld;
  }
  return ServerCompatibility.compatible;
}

/// True for the `0.0`/`0.0.0`/`0.0.0-dev` family of unversioned builds.
bool _isDev(String version) =>
    version == _devVersion || version.startsWith('$_devVersion.');

/// Leading numeric component of a `major[.minor[.patch]][-suffix]` string, or
/// null when it isn't a number.
int? _majorOf(String version) {
  final head = version.split('.').first.split('-').first;
  return int.tryParse(head);
}

/// Orders two dotted version strings numerically, shorter treated as zeroes
/// (`1.2` == `1.2.0`). Pre-release suffixes are ignored: this only ever
/// compares against an operator-set floor, where `1.2.0-rc1` vs `1.2.0`
/// precedence is not a distinction worth locking anyone out over.
int _compare(String a, String b) {
  final left = _segments(a);
  final right = _segments(b);
  for (var i = 0; i < 3; i++) {
    final diff =
        (i < left.length ? left[i] : 0) - (i < right.length ? right[i] : 0);
    if (diff != 0) return diff < 0 ? -1 : 1;
  }
  return 0;
}

List<int> _segments(String version) => version
    .split('-')
    .first
    .split('.')
    .map((s) => int.tryParse(s) ?? 0)
    .toList();

/// Compatibility of the running build with the configured server.
///
/// Kept alive alongside [serverInfoProvider]: a login screen blocks on this
/// before offering any sign-in control.
final serverCompatibilityProvider = FutureProvider<ServerCompatibility>(
  (
    ref,
  ) async {
    final version = await ref.watch(appVersionProvider.future);
    final info = await ref.watch(serverInfoProvider.future);
    return checkServerCompatibility(appVersion: version, info: info);
  },
  name: 'serverCompatibilityProvider',
);
