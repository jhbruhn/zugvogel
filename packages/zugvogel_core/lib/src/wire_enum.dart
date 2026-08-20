import 'package:zugvogel_core/src/converters.dart';

/// The contract every domain enum in a Zugvogel app implements.
///
/// The enums themselves are domain — `CaseStatus`, `EggFate`, `Sex` belong to
/// one product and never move into this package. The *pattern* does: each
/// constant carries the exact string PocketBase stores, so a rename of the
/// Dart identifier cannot change what is written to the database, and
/// snake_case never leaks out of the mapping layer.
///
/// ```dart
/// enum CaseStatus implements WireEnum {
///   inCare('in_care'),
///   disposed('disposed');
///
///   const CaseStatus(this.wire);
///
///   @override
///   final String wire;
///
///   static CaseStatus? fromWire(Object? v) => wireEnum(values, v);
/// }
/// ```
///
/// A `fromWire` that returns `null` rather than throwing is deliberate: a
/// select value this build does not know about is one unreadable field on one
/// record, not a crashed list.
abstract interface class WireEnum {
  /// The exact string stored in the PocketBase select field.
  String get wire;
}

/// [pbEnum] for enums that implement [WireEnum] — saves every enum repeating
/// the `(e) => e.wire` accessor.
T? wireEnum<T extends WireEnum>(Iterable<T> values, Object? raw) =>
    pbEnum(values, (e) => e.wire, raw);

/// [pbEnumList] for enums that implement [WireEnum].
List<T> wireEnumList<T extends WireEnum>(Iterable<T> values, Object? raw) =>
    pbEnumList(values, (e) => e.wire, raw);
