import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:test/test.dart';
import 'package:zugvogel_data/zugvogel_data.dart';

import 'support/thing.dart';

class _MockPb extends Mock implements PocketBase {}

class _MockService extends Mock implements RecordService {}

class _ThingsRepo extends PbRepository<Thing> {
  _ThingsRepo(PocketBase pb)
    : super(pb: pb, collection: 'things', fromRecord: Thing.fromRecord);
}

/// Captures what `page()` actually asked the server for.
class _Ask {
  const _Ask(this.filter, this.sort, this.perPage, this.fields);
  final String? filter;
  final String? sort;
  final int? perPage;
  final String? fields;
}

void main() {
  late _MockPb pb;
  late _MockService service;
  late _ThingsRepo repo;
  late List<_Ask> asks;

  /// Answers `getList` with [rows] and records the request.
  void answerWith(List<RecordModel> Function() rows) {
    when(
      () => service.getList(
        page: any(named: 'page'),
        perPage: any(named: 'perPage'),
        skipTotal: any(named: 'skipTotal'),
        filter: any(named: 'filter'),
        sort: any(named: 'sort'),
        expand: any(named: 'expand'),
        fields: any(named: 'fields'),
      ),
    ).thenAnswer((i) async {
      asks.add(
        _Ask(
          i.namedArguments[#filter] as String?,
          i.namedArguments[#sort] as String?,
          i.namedArguments[#perPage] as int?,
          i.namedArguments[#fields] as String?,
        ),
      );
      return ResultList(items: rows());
    });
  }

  setUp(() {
    pb = _MockPb();
    service = _MockService();
    asks = [];
    when(() => pb.collection('things')).thenReturn(service);
    // Stand in for the SDK's binder: splice the params in so the assertions
    // can read the predicate that was actually built.
    when(() => pb.filter(any(), any())).thenAnswer((i) {
      var expr = i.positionalArguments.first as String;
      final params =
          (i.positionalArguments[1] as Map<String, dynamic>?) ?? const {};
      for (final e in params.entries) {
        expr = expr.replaceAll('{:${e.key}}', "'${e.value}'");
      }
      return expr;
    });
    repo = _ThingsRepo(pb);
  });

  RecordModel row(String id, String created) =>
      thingRecord(id, 'Thing $id', created: created);

  group('the sort key', () {
    test('orders by the field AND id, both descending by default', () {
      expect(PbSortKey.newestCreated.sort, '-created,-id');
      expect(const PbSortKey('name').sort, '-name,-id');
      expect(const PbSortKey('name', descending: false).sort, 'name,id');
    });

    test('page() sorts by exactly that key, nothing else', () async {
      answerWith(() => [row('r1', '2026-08-01 10:00:00.000Z')]);

      await repo.page(perPage: 10);

      expect(asks.single.sort, '-created,-id');
      expect(asks.single.perPage, 10);
    });

    test('equality is by field and direction', () {
      expect(const PbSortKey('name'), const PbSortKey('name'));
      expect(
        const PbSortKey('name'),
        isNot(const PbSortKey('name', descending: false)),
      );
      expect(
        const PbSortKey('name').hashCode,
        const PbSortKey('name').hashCode,
      );
    });
  });

  group('the first page', () {
    test('asks for no resume predicate', () async {
      answerWith(() => [row('r1', '2026-08-01 10:00:00.000Z')]);

      await repo.page(perPage: 10);

      expect(asks.single.filter, isNull);
    });

    test('a short page ends the sequence', () async {
      answerWith(() => [row('r1', '2026-08-01 10:00:00.000Z')]);

      final p = await repo.page(perPage: 10);

      expect(p.items, hasLength(1));
      expect(p.hasMore, isFalse);
      expect(p.cursor, isNull);
    });

    test(
      'a FULL page hands back a cursor, even if it is the last one',
      () async {
        // A full page might be the end too. Handing back a cursor costs one
        // more request to settle it, which is the trade against stopping early
        // on a boundary and silently losing the tail.
        answerWith(
          () => [
            row('r1', '2026-08-02 10:00:00.000Z'),
            row('r2', '2026-08-01 10:00:00.000Z'),
          ],
        );

        final p = await repo.page(perPage: 2);

        expect(p.hasMore, isTrue);
        expect(p.cursor, isNotNull);
        // The cursor is the LAST row of the page — the oldest, walking down.
        expect(p.cursor!.id, 'r2');
        expect(p.cursor!.value, '2026-08-01 10:00:00.000Z');
      },
    );

    test('an empty page ends the sequence', () async {
      answerWith(() => []);

      final p = await repo.page(perPage: 10);

      expect(p.items, isEmpty);
      expect(p.hasMore, isFalse);
    });
  });

  group('resuming', () {
    test(
      'asks for "older than the last row I saw", ties broken by id',
      () async {
        answerWith(() => [row('r3', '2026-07-30 10:00:00.000Z')]);

        await repo.page(
          perPage: 10,
          after: const PbCursor(
            value: '2026-08-01 10:00:00.000Z',
            id: 'r2',
          ),
        );

        // Both halves matter. The `<` walks down the order; the `=` arm is what
        // makes a tied key value reachable exactly once — a `created` key is
        // stored to the millisecond, and two rows written inside the same one
        // would otherwise be either skipped or repeated forever.
        final f = asks.single.filter!;
        expect(f, contains("created < '2026-08-01 10:00:00.000Z'"));
        expect(f, contains("created = '2026-08-01 10:00:00.000Z'"));
        expect(f, contains("id < 'r2'"));
        expect(f, contains('||'));
      },
    );

    test('walking UP the order flips both comparisons', () async {
      answerWith(() => [row('r3', '2026-08-05 10:00:00.000Z')]);

      await repo.page(
        sortKey: const PbSortKey('created', descending: false),
        after: const PbCursor(value: '2026-08-01 10:00:00.000Z', id: 'r2'),
      );

      final f = asks.single.filter!;
      expect(f, contains("created > '2026-08-01 10:00:00.000Z'"));
      expect(f, contains("id > 'r2'"));
      expect(f, isNot(contains('<')));
      expect(asks.single.sort, 'created,id');
    });

    test(
      'a caller filter is ANDed with the resume predicate, not replaced',
      () async {
        // Losing the caller's filter here would quietly widen the query to the
        // whole collection on page two.
        answerWith(() => [row('r3', '2026-07-30 10:00:00.000Z')]);

        await repo.page(
          filter: repo.filterExpr('org = {:o}', {'o': 'org1'}),
          after: const PbCursor(value: '2026-08-01 10:00:00.000Z', id: 'r2'),
        );

        final f = asks.single.filter!;
        expect(f, contains("org = 'org1'"));
        expect(f, contains('&&'));
        expect(f, startsWith('('));
      },
    );

    test('a growing feed neither skips nor repeats a row', () async {
      // The property offsets cannot hold. Rows arrive between the two
      // requests; with ?page=2 the window shifts and the reader sees some rows
      // twice and misses others. Asking for "older than r2" cannot, however
      // much lands in between.
      final feed = <RecordModel>[
        row('r5', '2026-08-05 10:00:00.000Z'),
        row('r4', '2026-08-04 10:00:00.000Z'),
        row('r3', '2026-08-03 10:00:00.000Z'),
        row('r2', '2026-08-02 10:00:00.000Z'),
        row('r1', '2026-08-01 10:00:00.000Z'),
      ];
      // The mock is a tiny keyset server over `feed`, newest first.
      when(
        () => service.getList(
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
          skipTotal: any(named: 'skipTotal'),
          filter: any(named: 'filter'),
          sort: any(named: 'sort'),
          expand: any(named: 'expand'),
          fields: any(named: 'fields'),
        ),
      ).thenAnswer((i) async {
        final filter = i.namedArguments[#filter] as String?;
        final perPage = i.namedArguments[#perPage] as int;
        var rows = [...feed];
        if (filter != null) {
          final m = RegExp("created < '([^']+)'").firstMatch(filter)!;
          final cutoff = m.group(1)!;
          rows = rows
              .where((r) => '${r.data['created']}'.compareTo(cutoff) < 0)
              .toList();
        }
        return ResultList(items: rows.take(perPage).toList());
      });

      final seen = <String>[];
      PbCursor? cursor;
      var guardCount = 0;
      do {
        final p = await repo.page(perPage: 2, after: cursor);
        seen.addAll(p.items.map((t) => t.id));
        cursor = p.cursor;
        // Two rows land at the TOP of the feed between requests — exactly what
        // breaks offset paging.
        if (guardCount == 0) {
          feed.insertAll(0, [
            row('r7', '2026-08-07 10:00:00.000Z'),
            row('r6', '2026-08-06 10:00:00.000Z'),
          ]);
        }
        guardCount++;
      } while (cursor != null && guardCount < 10);

      // r5..r1 each exactly once. The two rows added mid-read are newer than
      // where the reader already was, so they are simply not in this pass —
      // which is correct, and is not the same as being skipped forever: a
      // fresh pass from the top picks them up.
      expect(seen, ['r5', 'r4', 'r3', 'r2', 'r1']);
      expect(seen.toSet(), hasLength(seen.length));
    });
  });

  group('a projection', () {
    test(
      'always gets the sort key and id back, or the cursor is unbuildable',
      () async {
        // A caller asking for `fields: 'name'` would otherwise get pages whose
        // last row has no `created` — so no cursor, so paging stops after one
        // page with no indication anything is missing.
        answerWith(
          () => [
            row('r1', '2026-08-02 10:00:00.000Z'),
            row('r2', '2026-08-01 10:00:00.000Z'),
          ],
        );

        final p = await repo.page(perPage: 2, fields: 'name');

        final requested = asks.single.fields!.split(',').toSet();
        expect(requested, containsAll(['name', 'id', 'created']));
        expect(p.cursor, isNotNull);
      },
    );

    test('no projection asks for no projection', () async {
      answerWith(() => [row('r1', '2026-08-01 10:00:00.000Z')]);

      await repo.page(perPage: 10);

      expect(asks.single.fields, isNull);
    });
  });

  group('PbCursor', () {
    test('is equal by value and id', () {
      expect(
        const PbCursor(value: 'v', id: 'i'),
        const PbCursor(value: 'v', id: 'i'),
      );
      expect(
        const PbCursor(value: 'v', id: 'i'),
        isNot(const PbCursor(value: 'v', id: 'j')),
      );
      expect(
        const PbCursor(value: 'v', id: 'i').hashCode,
        const PbCursor(value: 'v', id: 'i').hashCode,
      );
    });

    test('carries the value verbatim, so no reformat can shift it', () async {
      // The value is passed back to the server as a string comparison. Parsing
      // it to a DateTime and re-formatting could round the millisecond and
      // move the boundary.
      answerWith(
        () => [
          row('r1', '2026-08-02 10:00:00.123Z'),
          row('r2', '2026-08-01 10:00:00.456Z'),
        ],
      );

      final p = await repo.page(perPage: 2);

      expect(p.cursor!.value, '2026-08-01 10:00:00.456Z');
    });

    test('reads back in a log line', () {
      expect(
        const PbCursor(value: 'v', id: 'i').toString(),
        'PbCursor(v, i)',
      );
    });
  });
}
