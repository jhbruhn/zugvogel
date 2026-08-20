import 'package:test/test.dart';
import 'package:zugvogel_core/zugvogel_core.dart';

void main() {
  group('GeoPoint.fromPb', () {
    test('reads a real pin', () {
      final p = GeoPoint.fromPb({'lon': 8.05, 'lat': 52.28});
      expect(p, const GeoPoint(lon: 8.05, lat: 52.28));
    });

    test('an unset pin — {lon: 0, lat: 0} — is null, not Null Island', () {
      // THE rule this class exists for. PocketBase has no null for a geoPoint,
      // so clearing one stores {0, 0}. Read literally that is a real place in
      // the Gulf of Guinea a few hundred kilometres off Ghana, which renders
      // as a perfectly plausible marker instead of as missing data — every
      // un-pinned record piling up on one spot in the Atlantic.
      expect(GeoPoint.fromPb({'lon': 0, 'lat': 0}), isNull);
      expect(GeoPoint.fromPb({'lon': 0.0, 'lat': 0.0}), isNull);
    });

    test('a genuine zero on ONE axis survives', () {
      // Only the pair is the sentinel. The prime meridian and the equator are
      // real lines that run through inhabited places.
      expect(GeoPoint.fromPb({'lon': 0, 'lat': 51.48}), isNotNull);
      expect(GeoPoint.fromPb({'lon': 8.05, 'lat': 0}), isNotNull);
    });

    test('missing, malformed and non-map values are null', () {
      expect(GeoPoint.fromPb(null), isNull);
      expect(GeoPoint.fromPb(''), isNull);
      expect(GeoPoint.fromPb('8.05,52.28'), isNull);
      expect(GeoPoint.fromPb(<String, Object?>{}), isNull);
      expect(GeoPoint.fromPb({'lon': 8.05}), isNull);
      expect(GeoPoint.fromPb({'lat': 52.28}), isNull);
    });

    test('integer coordinates are widened to double', () {
      final p = GeoPoint.fromPb({'lon': 8, 'lat': 52});
      expect(p, const GeoPoint(lon: 8, lat: 52));
    });
  });

  group('value semantics', () {
    test('equal by coordinates', () {
      expect(
        const GeoPoint(lon: 1, lat: 2),
        const GeoPoint(lon: 1, lat: 2),
      );
      expect(
        const GeoPoint(lon: 1, lat: 2).hashCode,
        const GeoPoint(lon: 1, lat: 2).hashCode,
      );
      expect(
        const GeoPoint(lon: 1, lat: 2),
        isNot(const GeoPoint(lon: 2, lat: 1)),
      );
    });

    test('copyWith replaces one axis', () {
      expect(
        const GeoPoint(lon: 1, lat: 2).copyWith(lat: 3),
        const GeoPoint(lon: 1, lat: 3),
      );
    });

    test('toPb round-trips through fromPb', () {
      const p = GeoPoint(lon: 8.05, lat: 52.28);
      expect(GeoPoint.fromPb(p.toPb()), p);
    });

    test('toString is readable in a log line', () {
      expect(
        const GeoPoint(lon: 1.5, lat: 2.5).toString(),
        'GeoPoint(lon: 1.5, lat: 2.5)',
      );
    });
  });
}
