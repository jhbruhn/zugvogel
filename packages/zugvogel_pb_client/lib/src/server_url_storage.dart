import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zugvogel_pb_client/src/config.dart';

/// Persists the native-only, user-entered server URL. Not secret, so plain
/// `shared_preferences` rather than the keychain. Web never reads this — its
/// base URL is the serving origin.
class ServerUrlStorage {
  const ServerUrlStorage({required this.key});

  /// Storage key, namespaced per app — see
  /// [PbClientConfig.serverUrlStorageKey].
  final String key;

  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);

  Future<void> write(String url) async =>
      (await SharedPreferences.getInstance()).setString(key, url);

  Future<void> delete() async =>
      (await SharedPreferences.getInstance()).remove(key);
}

final serverUrlStorageProvider = Provider<ServerUrlStorage>(
  (ref) => ServerUrlStorage(
    key: ref.watch(pbClientConfigProvider).serverUrlStorageKey,
  ),
);
