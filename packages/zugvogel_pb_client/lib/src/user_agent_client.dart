import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zugvogel_pb_client/src/config.dart';

/// Builds an app's HTTP `User-Agent`, e.g. `federfall/1.2.3`.
///
/// The PocketBase Dart SDK never sets a `User-Agent`, so requests otherwise go
/// out with the platform default (`Dart/<v> (dart:io)` on native). The version
/// comes from the running build via [PackageInfo] (driven by release-please
/// through `pubspec.yaml`); it falls back to `0.0.0` when unavailable.
Future<String> loadUserAgent(String name) async =>
    '$name/${await loadAppVersion()}';

/// The running build's version (e.g. `1.2.3`), or `0.0.0` when [PackageInfo]
/// cannot resolve one.
Future<String> loadAppVersion() async {
  final info = await PackageInfo.fromPlatform();
  return info.version.isEmpty ? '0.0.0' : info.version;
}

/// The app-wide HTTP `User-Agent` string. Resolved once and cached.
final userAgentProvider = FutureProvider<String>(
  (ref) => loadUserAgent(ref.watch(pbClientConfigProvider).userAgentName),
);

/// The running build's version, for display on a profile/about screen.
final appVersionProvider = FutureProvider<String>((ref) => loadAppVersion());

/// An [http.Client] that stamps a fixed `User-Agent` on every request before
/// delegating to its inner client.
///
/// Pass it to `PocketBase(..., httpClientFactory: ...)` so every call the SDK
/// makes identifies the app instead of using the platform HTTP default.
class UserAgentClient extends http.BaseClient {
  UserAgentClient(this.userAgent, [http.Client? inner])
    : _inner = inner ?? http.Client();

  /// The `User-Agent` value set on every outgoing request.
  final String userAgent;

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['user-agent'] = userAgent;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
