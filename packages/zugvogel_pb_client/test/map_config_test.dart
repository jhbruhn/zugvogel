import 'package:flutter_test/flutter_test.dart';
import 'package:zugvogel_pb_client/zugvogel_pb_client.dart';

import 'support/config.dart';

void main() {
  group('ServerMapConfig.tryParse is all-or-nothing', () {
    // Half-applied is the shape that does damage: a map serving one provider's
    // tiles under another's credit is a licensing problem. So the credit
    // travels with the URL, or neither applies.
    test('a complete raster block parses', () {
      final m = ServerMapConfig.tryParse({
        'mode': 'raster',
        'tileUrl': 'https://t.example/{z}/{x}/{y}.png',
        'attribution': '© Example',
        'attributionUrl': 'https://example.org/c',
        'apiKey': 'k',
      })!;
      expect(m.mode, MapMode.raster);
      expect(m.url, 'https://t.example/{z}/{x}/{y}.png');
      expect(m.attribution, '© Example');
      expect(m.attributionUrl, 'https://example.org/c');
      expect(m.apiKey, 'k');
    });

    test('a complete vector block parses', () {
      final m = ServerMapConfig.tryParse({
        'mode': 'vector',
        'styleUrl': 'https://t.example/style.json',
        'attribution': '© Example',
      })!;
      expect(m.mode, MapMode.vector);
      expect(m.url, 'https://t.example/style.json');
    });

    test('only the URL for the ACTIVE mode is read', () {
      // A stray key for the other rendering path must not leak into the wrong
      // one — that is how you end up drawing a style JSON as a raster tile.
      expect(
        ServerMapConfig.tryParse({
          'mode': 'raster',
          'styleUrl': 'https://t.example/style.json',
          'attribution': '© Example',
        }),
        isNull,
      );
    });

    test('rejects a missing or unknown mode', () {
      expect(ServerMapConfig.tryParse({'attribution': 'x'}), isNull);
      expect(
        ServerMapConfig.tryParse({'mode': 'satellite', 'attribution': 'x'}),
        isNull,
      );
    });

    test('rejects a URL that is not http(s)', () {
      // Everything downstream feeds this to an image/fetch load.
      for (final url in [
        'file:///etc/passwd',
        'javascript:alert(1)',
        'data:image/png;base64,AAAA',
        '//t.example/{z}/{x}/{y}.png',
        '',
      ]) {
        expect(
          ServerMapConfig.tryParse({
            'mode': 'raster',
            'tileUrl': url,
            'attribution': '© Example',
          }),
          isNull,
          reason: url,
        );
      }
    });

    test('rejects a URL with no attribution', () {
      expect(
        ServerMapConfig.tryParse({
          'mode': 'raster',
          'tileUrl': 'https://t.example/{z}/{x}/{y}.png',
        }),
        isNull,
      );
      expect(
        ServerMapConfig.tryParse({
          'mode': 'raster',
          'tileUrl': 'https://t.example/{z}/{x}/{y}.png',
          'attribution': '',
        }),
        isNull,
      );
    });

    test('empty optionals become null, not empty strings', () {
      final m = ServerMapConfig.tryParse({
        'mode': 'raster',
        'tileUrl': 'https://t.example/{z}/{x}/{y}.png',
        'attribution': '© Example',
        'attributionUrl': '',
        'apiKey': '',
      })!;
      // Absent → plain text, rather than linking a page that describes some
      // other provider.
      expect(m.attributionUrl, isNull);
      expect(m.apiKey, isNull);
    });

    test('rejects a non-map block', () {
      expect(ServerMapConfig.tryParse(null), isNull);
      expect(ServerMapConfig.tryParse('raster'), isNull);
    });
  });

  group('MapConfig.resolve', () {
    test('keeps the app fallback when the server prescribes nothing', () {
      // Fails open exactly like the rest of /info discovery: no prescription,
      // an older server without the key, or an unreachable /info.
      expect(
        MapConfig.resolve(null, fallback: testMapFallback),
        testMapFallback,
      );
    });

    test('the server wins, wholesale', () {
      final resolved = MapConfig.resolve(
        const ServerMapConfig(
          mode: MapMode.vector,
          url: 'https://s.example/style.json',
          attribution: '© Server',
        ),
        fallback: testMapFallback,
      );
      expect(resolved.mode, MapMode.vector);
      expect(resolved.url, 'https://s.example/style.json');
      expect(resolved.attribution, '© Server');
      // NOT merged field-by-field: the fallback's attributionUrl does not
      // survive onto the server's provider.
      expect(resolved.attributionUrl, isNull);
    });
  });

  group('rasterUrl', () {
    test('substitutes the {key} token, url-encoded', () {
      const m = MapConfig(
        mode: MapMode.raster,
        url: 'https://t.example/{z}/{x}/{y}.png?key={key}',
        attribution: '© Example',
        apiKey: 'a b/c',
      );
      // flutter_map only knows {z}/{x}/{y} and would request the literal
      // token; encoded as a query component, matching the vector side.
      expect(m.rasterUrl, 'https://t.example/{z}/{x}/{y}.png?key=a+b%2Fc');
    });

    test('substitutes an empty string when there is no key', () {
      const m = MapConfig(
        mode: MapMode.raster,
        url: 'https://t.example/{z}/{x}/{y}.png?key={key}',
        attribution: '© Example',
      );
      expect(m.rasterUrl, 'https://t.example/{z}/{x}/{y}.png?key=');
    });

    test('leaves a keyless template alone', () {
      expect(testMapFallback.rasterUrl, testMapFallback.url);
    });
  });

  test('value equality, so a provider watching /info does not thrash', () {
    expect(
      MapConfig.resolve(null, fallback: testMapFallback),
      MapConfig.resolve(null, fallback: testMapFallback),
    );
    expect(
      MapConfig.resolve(null, fallback: testMapFallback).hashCode,
      MapConfig.resolve(null, fallback: testMapFallback).hashCode,
    );
  });
}
