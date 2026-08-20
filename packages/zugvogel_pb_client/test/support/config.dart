import 'package:zugvogel_pb_client/zugvogel_pb_client.dart';

/// A fallback map source standing in for what an app builds from its defines.
const testMapFallback = MapConfig(
  mode: MapMode.raster,
  url: 'https://tile.example/{z}/{x}/{y}.png',
  attribution: '© Example',
  attributionUrl: 'https://example.org/copyright',
);

/// Config for a fictional app, so no test leans on either real service name.
PbClientConfig testConfig({
  String service = 'testvogel',
  bool allowInsecureHttp = false,
  String? webBaseUrlOverride,
  MapConfig? mapFallback,
}) => PbClientConfig(
  service: service,
  fallbackServerName: 'Testvogel',
  mapFallback: mapFallback ?? testMapFallback,
  allowInsecureHttp: allowInsecureHttp,
  webBaseUrlOverride: webBaseUrlOverride,
);
