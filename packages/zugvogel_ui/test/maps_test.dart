import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zugvogel_pb_client/zugvogel_pb_client.dart';
import 'package:zugvogel_ui/zugvogel_ui.dart';

/// A tree with the map config the server (or the fallback) resolved to.
///
/// Built inline rather than through the shared `host` helper because it needs a
/// provider override, and riverpod does not export the `Override` type for a
/// helper to accept one.
Widget attributionHost(MapConfig config) => ProviderScope(
  overrides: [
    pbClientConfigProvider.overrideWithValue(
      PbClientConfig(
        service: 'testvogel',
        fallbackServerName: 'Testvogel',
        mapFallback: config,
      ),
    ),
  ],
  child: const MaterialApp(home: Scaffold(body: MapAttribution())),
);

void main() {
  group('MapWheelZoom', () {
    test("its flags drop flutter_map's own wheel zoom", () {
      // Leaving it on would run both handlers and re-introduce the fractional
      // zoom this widget exists to avoid.
      expect(
        MapWheelZoom.flags & InteractiveFlag.scrollWheelZoom,
        0,
      );
      // ...and keeps everything else, including pinch, which stays continuous:
      // snapping mid-gesture would fight the user's fingers.
      expect(MapWheelZoom.flags & InteractiveFlag.pinchZoom, isNot(0));
      expect(MapWheelZoom.flags & InteractiveFlag.drag, isNot(0));
      expect(MapWheelZoom.flags & InteractiveFlag.doubleTapZoom, isNot(0));
    });
  });

  group('MapAttribution', () {
    testWidgets('shows the credit for the source actually in use', (
      tester,
    ) async {
      // A licensing requirement, not decoration: every map must carry visible,
      // non-hidden attribution for whichever provider it is drawing.
      await tester.pumpWidget(
        attributionHost(
          const MapConfig(
            mode: MapMode.raster,
            url: 'https://t.example/{z}/{x}/{y}.png',
            attribution: '© Example contributors',
            attributionUrl: 'https://example.org/copyright',
          ),
        ),
      );
      expect(find.text('© Example contributors'), findsOneWidget);
      // Linked, as the OSMF guidelines recommend for an interactive map.
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('a source with no copyright page renders as plain text', (
      tester,
    ) async {
      // Absent link → plain text, rather than linking a page that describes
      // some other provider.
      await tester.pumpWidget(
        attributionHost(
          const MapConfig(
            mode: MapMode.raster,
            url: 'https://t.example/{z}/{x}/{y}.png',
            attribution: '© Example contributors',
          ),
        ),
      );
      expect(find.text('© Example contributors'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets("credits the SERVER's provider, never the built-in one", (
      tester,
    ) async {
      // The pairing that matters: a self-hoster who repoints the tiles must not
      // keep showing the credit that shipped in the build.
      await tester.pumpWidget(
        attributionHost(
          const MapConfig(
            mode: MapMode.vector,
            url: 'https://s.example/style.json',
            attribution: '© Somebody else',
          ),
        ),
      );
      expect(find.text('© Somebody else'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap'), findsNothing);
    });
  });

  group('MapTileLayer', () {
    test('requires the app to identify itself', () {
      // The OSM Tile Usage Policy asks the application to say who it is, and a
      // shared package cannot answer for it — every Zugvogel app would
      // identify as the same one.
      const layer = MapTileLayer(userAgentPackageName: 'de.example.app');
      expect(layer.userAgentPackageName, 'de.example.app');
    });
  });
}
