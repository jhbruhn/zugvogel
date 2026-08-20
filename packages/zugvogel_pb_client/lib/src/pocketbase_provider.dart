import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:zugvogel_pb_client/src/auth_token_storage.dart';
import 'package:zugvogel_pb_client/src/server_config.dart';
import 'package:zugvogel_pb_client/src/server_config_controller.dart';
import 'package:zugvogel_pb_client/src/user_agent_client.dart';

/// Thrown when the PocketBase client is requested on native before a server
/// URL has been configured. Routing gates on [ServerConfigController], so this
/// should only ever surface as a programming error.
class ServerNotConfiguredException implements Exception {
  const ServerNotConfiguredException();

  @override
  String toString() => 'ServerNotConfiguredException: no server URL configured';
}

/// The app-wide [PocketBase] client.
///
/// Built asynchronously because restoring a session requires reading the
/// persisted auth payload first; that initial value seeds an [AsyncAuthStore]
/// whose `save`/`clear` write back through [AuthTokenStorage]. The provider is
/// keyed on [ServerConfigController], so switching servers (native) rebuilds a
/// fresh client pointed at the new origin with a clean auth store.
final pocketBaseProvider = FutureProvider<PocketBase>(
  (ref) async {
    final config = await ref.watch(serverConfigControllerProvider.future);
    final baseUrl = switch (config) {
      ServerConfigured(:final baseUrl) => baseUrl,
      ServerUnconfigured() => throw const ServerNotConfiguredException(),
    };

    final storage = ref.watch(authTokenStorageProvider);
    final initial = await storage.read();
    final ua = await ref.watch(userAgentProvider.future);

    final authStore = AsyncAuthStore(
      save: storage.write,
      clear: storage.delete,
      initial: initial,
    );

    return PocketBase(
      baseUrl,
      authStore: authStore,
      httpClientFactory: () => UserAgentClient(ua),
    );
  },
  name: 'pocketBaseProvider',
);
