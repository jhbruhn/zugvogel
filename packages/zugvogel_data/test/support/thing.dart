import 'package:pocketbase/pocketbase.dart';
import 'package:zugvogel_core/zugvogel_core.dart';

/// A stand-in domain model for exercising the generic repository base.
///
/// The real models are domain and live in the apps; this is the smallest thing
/// with a mapper that can fail, which is what the base class's contract is
/// about.
class Thing {
  const Thing({required this.id, required this.name, this.created});

  factory Thing.fromRecord(RecordModel r) => Thing(
    id: r.id,
    name: pbString(r.data['name']) ?? '',
    created: pbDate(r.data['created']),
  );

  final String id;
  final String name;
  final DateTime? created;
}

/// Builds a raw record the way PocketBase would return one.
RecordModel thingRecord(String id, String name, {String? created}) =>
    RecordModel({'id': id, 'name': name, 'created': ?created});
