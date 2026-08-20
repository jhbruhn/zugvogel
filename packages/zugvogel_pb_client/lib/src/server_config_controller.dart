import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zugvogel_pb_client/src/auth_token_storage.dart';
import 'package:zugvogel_pb_client/src/config.dart';
import 'package:zugvogel_pb_client/src/server_config.dart';
import 'package:zugvogel_pb_client/src/server_url_storage.dart';

/// Resolves and owns the [ServerConfig] for the running app, and lets a native
/// setup flow change it.
///
/// Resolution rules:
///   * **web** — always configured; the base URL is the app's serving origin
///     (`Uri.base.origin`), since backend and frontend share the domain. A
///     build-time override ([PbClientConfig.webBaseUrlOverride]) wins, for a
///     dev setup where they run on different ports.
///   * **native** — the persisted URL, or [ServerUnconfigured] when unset, so
///     first run always lands on the setup screen. The build-time override
///     never auto-configures here (that would skip setup); it only *prefills*
///     the setup field.
///
/// Mutating the URL replaces the state, which transitively rebuilds the
/// PocketBase client (it is keyed on this config).
class ServerConfigController extends AsyncNotifier<ServerConfig> {
  @override
  Future<ServerConfig> build() async {
    if (kIsWeb) {
      return ServerConfig.configured(_webBaseUrl());
    }

    final stored = await ref.watch(serverUrlStorageProvider).read();
    if (stored != null && stored.isNotEmpty) {
      return ServerConfig.configured(stored);
    }

    return const ServerConfig.unconfigured();
  }

  /// Persists [url] as the active native server and switches to it.
  ///
  /// A persisted auth payload belongs to the origin it was issued by, so it is
  /// purged whenever the URL actually changes — otherwise the rebuilt
  /// PocketBase client would send the previous server's bearer token to the
  /// new (potentially untrusted) host.
  Future<void> setServerUrl(String url) async {
    final urlStorage = ref.read(serverUrlStorageProvider);
    final previous = await urlStorage.read();
    if (previous != url) {
      await ref.read(authTokenStorageProvider).delete();
    }
    await urlStorage.write(url);
    state = AsyncData(ServerConfig.configured(url));
  }

  /// Forgets the native server URL, returning to the setup gate. The persisted
  /// auth payload goes with it (see [setServerUrl]).
  Future<void> clearServerUrl() async {
    await ref.read(serverUrlStorageProvider).delete();
    await ref.read(authTokenStorageProvider).delete();
    state = const AsyncData(ServerConfig.unconfigured());
  }

  /// On web the app and backend share an origin; a build-time override takes
  /// precedence.
  String _webBaseUrl() {
    final config = ref.read(pbClientConfigProvider);
    return config.hasWebBaseUrlOverride
        ? config.webBaseUrlOverride!
        : Uri.base.origin;
  }
}

final serverConfigControllerProvider =
    AsyncNotifierProvider<ServerConfigController, ServerConfig>(
      ServerConfigController.new,
      name: 'serverConfigControllerProvider',
    );
