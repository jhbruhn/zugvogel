import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zugvogel_core/zugvogel_core.dart';
import 'package:zugvogel_pb_client/src/config.dart';
import 'package:zugvogel_pb_client/src/pocketbase_provider.dart';
import 'package:zugvogel_pb_client/src/server_config.dart';
import 'package:zugvogel_pb_client/src/server_config_controller.dart';
import 'package:zugvogel_pb_client/src/server_info.dart';

/// The configured server's identity + capabilities, fetched from the
/// unauthenticated `GET /api/<service>/info` (federfall-7nf.1).
///
/// Null when no server is configured yet, or when the endpoint cannot be
/// reached/parsed — a login screen then falls back to its default option set
/// rather than blocking. Kept alive so a router gate can await it before the
/// login screen renders.
final serverInfoProvider = FutureProvider<ServerInfo?>(
  (ref) async {
    final config = await ref.watch(serverConfigControllerProvider.future);
    if (config is! ServerConfigured) return null;

    final clientConfig = ref.watch(pbClientConfigProvider);
    final pb = await ref.watch(pocketBaseProvider.future);
    try {
      // Capped like ServerProbe: a router gate holds unauthenticated users
      // on a splash screen while this loads, so a black-holed server must
      // fail fast into the null fallback instead of parking them on the
      // spinner for the OS socket timeout.
      final info = await pb
          .send(clientConfig.infoPath)
          .timeout(clientConfig.probeTimeout);
      return ServerInfo.tryParse(
        info,
        service: clientConfig.service,
        fallbackName: clientConfig.fallbackServerName,
      );
    } on Object catch (error, stackTrace) {
      reportCaughtError(error, stackTrace);
      return null;
    }
  },
  name: 'serverInfoProvider',
);
