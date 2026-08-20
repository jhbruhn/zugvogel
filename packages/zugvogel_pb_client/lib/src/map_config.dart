import 'package:meta/meta.dart';

/// Map tile rendering path.
enum MapMode {
  /// A MapLibre style JSON rendered through `vector_map_tiles`.
  vector,

  /// A classic `{z}/{x}/{y}` raster tile server drawn as plain images.
  raster,
}

/// A complete map source prescribed by the server, from `/info`'s `map` key.
///
/// Exists so a self-hoster can repoint the maps on a published container
/// image, which otherwise only ships whatever tile server was baked into the
/// build as a dart-define (federfall-el1f).
///
/// There is deliberately no partial form: [tryParse] rejects anything that is
/// not a mode plus the URL for *that* mode plus an [attribution], and the
/// server refuses to send one. Half-applied is the shape that does damage — a
/// map serving one provider's tiles under another's credit is a licensing
/// problem, so the credit travels with the URL or neither applies.
@immutable
class ServerMapConfig {
  const ServerMapConfig({
    required this.mode,
    required this.url,
    required this.attribution,
    this.attributionUrl,
    this.apiKey,
  });

  /// Parses the `map` block, returning null unless it is complete and usable —
  /// the caller then keeps its own defaults.
  static ServerMapConfig? tryParse(Object? json) {
    if (json is! Map) return null;

    final mode = switch (json['mode']) {
      'raster' => MapMode.raster,
      'vector' => MapMode.vector,
      _ => null,
    };
    if (mode == null) return null;

    // Only the URL belonging to the active mode is read, so a stray key for
    // the other rendering path cannot leak into the wrong one.
    final url =
        (mode == MapMode.raster ? json['tileUrl'] : json['styleUrl'])
            as String? ??
        '';
    // http(s) only: everything downstream feeds this to an image/fetch load,
    // and a scheme we did not expect has no business being handed there.
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;

    final attribution = json['attribution'] as String? ?? '';
    if (attribution.isEmpty) return null;

    final attributionUrl = json['attributionUrl'] as String?;
    final apiKey = json['apiKey'] as String?;
    return ServerMapConfig(
      mode: mode,
      url: url,
      attribution: attribution,
      // Optional: the visible credit is the licence requirement, the link to a
      // copyright page only the OSMF's recommendation. Absent → plain text,
      // rather than linking a page that describes some other provider.
      attributionUrl: (attributionUrl?.isEmpty ?? true) ? null : attributionUrl,
      apiKey: (apiKey?.isEmpty ?? true) ? null : apiKey,
    );
  }

  /// Which rendering path to use, see [MapMode].
  final MapMode mode;

  /// The MapLibre style JSON URL in [MapMode.vector], or the `{z}/{x}/{y}`
  /// raster template in [MapMode.raster] — one field, because only ever one of
  /// them is in play.
  final String url;

  /// Credit line the map must display for [url]'s provider. Never empty.
  final String attribution;

  /// Copyright/licence page [attribution] links to, or null for plain text.
  final String? attributionUrl;

  /// The tile provider's API key, substituted for the `{key}` token in [url]
  /// and — in [MapMode.vector] — inside the style's own source/sprite/glyph
  /// URLs. Null for a provider that needs none.
  ///
  /// `/info` is unauthenticated, so this key is public by construction; the
  /// server-side comment in the info hook explains why that is nonetheless the
  /// least-bad place for it.
  final String? apiKey;

  @override
  bool operator ==(Object other) =>
      other is ServerMapConfig &&
      other.mode == mode &&
      other.url == url &&
      other.attribution == attribution &&
      other.attributionUrl == attributionUrl &&
      other.apiKey == apiKey;

  @override
  int get hashCode =>
      Object.hash(mode, url, attribution, attributionUrl, apiKey);
}

/// The map source actually in effect, after resolving the server's
/// prescription against the app's own fallback (federfall-el1f).
///
/// An app's build-time defines are baked into its web bundle and its APK, so
/// on a published container image they are not configuration at all — a
/// self-hoster cannot change them without rebuilding. The server can therefore
/// prescribe a source through `/info`, and that wins. It fails open exactly
/// like the rest of that endpoint's discovery: no prescription, an older
/// server without the `map` key, or an unreachable `/info` all land on the
/// app's fallback.
@immutable
class MapConfig {
  const MapConfig({
    required this.mode,
    required this.url,
    required this.attribution,
    this.attributionUrl,
    this.apiKey,
  });

  /// [server]'s prescription when it sent one, else [fallback].
  ///
  /// All-or-nothing on purpose — there is no field-by-field merge. Mixing the
  /// two sources is what produces a map that renders one provider's tiles
  /// under another's credit; [ServerMapConfig] is only ever parsed as a
  /// complete unit for the same reason.
  ///
  /// [fallback] is the app's, built from its own dart-defines. This package
  /// holds no configuration and cannot read a define (injection boundary 3).
  factory MapConfig.resolve(
    ServerMapConfig? server, {
    required MapConfig fallback,
  }) => server == null
      ? fallback
      : MapConfig(
          mode: server.mode,
          url: server.url,
          attribution: server.attribution,
          attributionUrl: server.attributionUrl,
          apiKey: server.apiKey,
        );

  /// Which rendering path the map widgets take, see [MapMode].
  final MapMode mode;

  /// MapLibre style JSON URL in [MapMode.vector], `{z}/{x}/{y}` raster
  /// template in [MapMode.raster].
  final String url;

  /// Credit line the map displays for [url]'s provider.
  final String attribution;

  /// Copyright/licence page [attribution] links to, or null for plain text.
  final String? attributionUrl;

  /// The tile provider's API key, or null when it needs none.
  ///
  /// Applied differently per mode, which is why it stays a separate field
  /// instead of being pre-substituted into [url]: the vector path hands it to
  /// `StyleReader`, which has to substitute it inside the style's own source,
  /// sprite and glyph URLs too — only the client can do that, while reading
  /// the style. In raster mode there is nothing further to reach, so
  /// [rasterUrl] resolves it up front.
  final String? apiKey;

  /// [url] ready for a raster tile layer: the `{key}` token substituted, since
  /// flutter_map only knows the `{z}/{x}/{y}` placeholders and would request
  /// the literal token. Encoded as a query component, matching what
  /// `vector_map_tiles` does on the vector side.
  String get rasterUrl =>
      url.replaceAll('{key}', Uri.encodeQueryComponent(apiKey ?? ''));

  @override
  bool operator ==(Object other) =>
      other is MapConfig &&
      other.mode == mode &&
      other.url == url &&
      other.attribution == attribution &&
      other.attributionUrl == attributionUrl &&
      other.apiKey == apiKey;

  @override
  int get hashCode =>
      Object.hash(mode, url, attribution, attributionUrl, apiKey);
}
