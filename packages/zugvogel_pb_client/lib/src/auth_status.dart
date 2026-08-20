import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zugvogel_pb_client/src/pocketbase_provider.dart';
import 'package:zugvogel_pb_client/src/server_config.dart';
import 'package:zugvogel_pb_client/src/server_config_controller.dart';

/// Whether there is a currently valid (non-expired) PocketBase session.
///
/// This is the minimal signal a router's redirect gate needs. Returns `false`
/// (rather than erroring) when no server is configured yet, so the gate can
/// send native users to the setup screen first.
class AuthStatus extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final config = await ref.watch(serverConfigControllerProvider.future);
    if (config is! ServerConfigured) return false;

    final pb = await ref.watch(pocketBaseProvider.future);

    // Re-evaluate whenever the session changes (login/logout/refresh).
    final sub = pb.authStore.onChange.listen((_) => ref.invalidateSelf());
    // Disposed during the awaits above? onDispose would throw; cancel inline.
    if (!ref.mounted) {
      await sub.cancel();
      return pb.authStore.isValid;
    }
    ref.onDispose(sub.cancel);

    return pb.authStore.isValid;
  }
}

final authStatusProvider = AsyncNotifierProvider<AuthStatus, bool>(
  AuthStatus.new,
);
