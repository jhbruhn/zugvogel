import 'package:meta/meta.dart';

/// A geographic pin, mirroring a PocketBase `geoPoint` field (`{lon, lat}`).
///
/// Hand-written rather than generated. It is two doubles, and keeping it free
/// of `freezed` keeps this whole package free of `build_runner` — a pure-Dart
/// package with no codegen step runs its tests in a fraction of the time and
/// needs no generate stage in CI. The generated `copyWith` was checked for
/// before dropping it: nothing in either app called it.
@immutable
class GeoPoint {
  const GeoPoint({required this.lon, required this.lat});

  /// Parses a raw PocketBase geoPoint map, or `null` when unset.
  ///
  /// PocketBase represents an unset pin as `{lon: 0, lat: 0}`, so that
  /// sentinel means "no pin". Reading it literally puts every un-pinned record
  /// at Null Island in the Gulf of Guinea — which is a real place, several
  /// hundred kilometres off Ghana, and therefore renders as a plausible
  /// looking marker on a map instead of as missing data.
  static GeoPoint? fromPb(Object? raw) {
    if (raw is! Map) return null;
    final lon = (raw['lon'] as num?)?.toDouble();
    final lat = (raw['lat'] as num?)?.toDouble();
    if (lon == null || lat == null) return null;
    if (lon == 0 && lat == 0) return null;
    return GeoPoint(lon: lon, lat: lat);
  }

  final double lon;
  final double lat;

  /// The wire shape PocketBase expects when writing the field back.
  Map<String, double> toPb() => {'lon': lon, 'lat': lat};

  GeoPoint copyWith({double? lon, double? lat}) =>
      GeoPoint(lon: lon ?? this.lon, lat: lat ?? this.lat);

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lon == lon && other.lat == lat;

  @override
  int get hashCode => Object.hash(lon, lat);

  @override
  String toString() => 'GeoPoint(lon: $lon, lat: $lat)';
}
