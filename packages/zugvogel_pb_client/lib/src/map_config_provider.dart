import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zugvogel_pb_client/src/config.dart';
import 'package:zugvogel_pb_client/src/map_config.dart';
import 'package:zugvogel_pb_client/src/server_info_provider.dart';

/// The resolved [MapConfig] for the configured server.
///
/// Watches [serverInfoProvider], so this is genuinely reactive rather than
/// read-once: while `/info` is still in flight (or if it fails) the value is
/// the app's fallback, and it swaps to the server's prescription when the fetch
/// lands. A router gate typically only awaits `/info` on the *unauthenticated*
/// path, so a warm start straight into a detail screen can build a map before
/// it resolves — the map widgets rebuild on the swap instead of assuming it is
/// already there.
final mapConfigProvider = Provider<MapConfig>(
  (ref) => MapConfig.resolve(
    ref.watch(serverInfoProvider).value?.map,
    fallback: ref.watch(pbClientConfigProvider).mapFallback,
  ),
  name: 'mapConfigProvider',
);
