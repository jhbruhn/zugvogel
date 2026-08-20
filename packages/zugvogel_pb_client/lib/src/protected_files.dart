import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zugvogel_pb_client/src/config.dart';
import 'package:zugvogel_pb_client/src/pocketbase_provider.dart';

/// A short-lived PocketBase file access token for fetching Protected file
/// fields.
///
/// One token is valid for any protected file the current user may read (~2 min
/// server TTL), so it is minted once and reused across a screen's images. The
/// result is cached briefly and then self-invalidated, so the next read
/// re-mints well before the server-side token expires. Append it to file URLs
/// via `PbReadOnlyRepository.fileUrl(..., token:)`.
final FutureProvider<String>
fileTokenProvider = FutureProvider.autoDispose<String>(
  (ref) async {
    final pb = await ref.watch(pocketBaseProvider.future);
    final token = await pb.files.getToken();
    // The provider may have been disposed during the awaits above; touching the
    // ref (keepAlive/onDispose) then throws, so bail with the token as-is.
    if (!ref.mounted) return token;
    // Cache under the ~2 min TTL, then drop so the next read mints a fresh one.
    final link = ref.keepAlive();
    final timer = Timer(const Duration(seconds: 90), link.close);
    ref.onDispose(timer.cancel);
    return token;
  },
  name: 'fileTokenProvider',
);

/// Disk + memory cache for a PocketBase instance's **Protected** file fields.
///
/// The token is appended lazily, at download time, so a previously cached
/// image renders instantly with no token round-trip.
///
/// `cacheKey` namespaces the on-device store (an sqlite db plus a file
/// directory). It is injected because two Zugvogel apps installed on the same
/// device must not share one: the caches hold different users' files, and a
/// shared store would serve one app's bytes to the other.
class ProtectedFileCacheManager extends CacheManager {
  ProtectedFileCacheManager({
    required Future<String> Function() tokenProvider,
    required String cacheKey,
  }) : super(
         Config(
           cacheKey,
           fileService: _ProtectedFileService(tokenProvider: tokenProvider),
         ),
       );
}

/// Mints a fresh file token and appends it to each request URL at fetch time,
/// so the token is only needed when bytes are actually downloaded.
class _ProtectedFileService extends HttpFileService {
  _ProtectedFileService({required this.tokenProvider});

  final Future<String> Function() tokenProvider;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final token = await tokenProvider();
    final base = Uri.parse(url);
    final withToken = base.replace(
      queryParameters: {...base.queryParameters, 'token': token},
    );
    return super.get(withToken.toString(), headers: headers);
  }
}

/// The shared cache manager for Protected file fields.
///
/// Synchronous and kept alive for the app's lifetime, so image widgets can read
/// it without gating on an async resolve. The token itself is still fetched
/// through [fileTokenProvider], but only when a real download happens.
///
/// Not disposed: like `DefaultCacheManager` it is an app-lifetime singleton,
/// and disposing an unused cache manager trips a flutter_cache_manager bug.
final protectedFileCacheManagerProvider = Provider<ProtectedFileCacheManager>(
  (ref) => ProtectedFileCacheManager(
    tokenProvider: () => ref.read(fileTokenProvider.future),
    cacheKey: '${ref.watch(pbClientConfigProvider).service}ProtectedFiles',
  ),
  name: 'protectedFileCacheManagerProvider',
);

/// Cache key for a PocketBase file URL, with any `token` query param stripped.
///
/// Callers pass token-free URLs (the token is appended lazily at download time
/// by [ProtectedFileCacheManager]), but this defends against a token leaking
/// into the URL: keying the cache on the token-free identity lets the cache —
/// memory and disk — reuse the bytes across token rotations. Without it every
/// rotation would look like a new image and re-download it.
String fileCacheKey(Uri url) {
  final params = {...url.queryParameters}..remove('token');
  final base = '${url.origin}${url.path}';
  if (params.isEmpty) return base;
  final query = params.entries
      .map(
        (e) =>
            '${Uri.encodeQueryComponent(e.key)}='
            '${Uri.encodeQueryComponent(e.value)}',
      )
      .join('&');
  return '$base?$query';
}
