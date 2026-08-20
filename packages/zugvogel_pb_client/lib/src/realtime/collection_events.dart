import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:zugvogel_core/zugvogel_core.dart';
import 'package:zugvogel_pb_client/src/connectivity.dart';
import 'package:zugvogel_pb_client/src/pocketbase_provider.dart';

/// A live stream of PocketBase realtime events for one collection (topic
/// `*`).
///
/// The building block of live-sync (Pattern A): feature providers listen to
/// this and simply re-fetch their data on a relevant event, so there is one
/// loader (the repositories) with realtime as just another trigger — never a
/// second, hand-merged copy of the list.
///
/// One shared subscription per collection (riverpod de-dupes the family key),
/// multiplexed over PocketBase's single SSE connection. It watches
/// `onlineStatusProvider`: no subscription while offline, and it re-subscribes
/// when connectivity returns. Subscription errors are swallowed — realtime is
/// best-effort and the static loaders stay the source of truth.
// riverpod does not export the type of a family provider
// (StreamProviderFamily), so it cannot be written down here.
// ignore: specify_nonobvious_property_types
final collectionEventsProvider = StreamProvider.autoDispose
    .family<RecordSubscriptionEvent, String>((ref, collection) async* {
      if (ref.watch(onlineStatusProvider).value == OnlineStatus.offline) return;

      final pb = await ref.watch(pocketBaseProvider.future);
      final controller = StreamController<RecordSubscriptionEvent>();

      UnsubscribeFunc? unsubscribe;
      try {
        unsubscribe = await pb
            .collection(collection)
            .subscribe('*', controller.add);
      } on Object catch (error, stackTrace) {
        reportCaughtError(error, stackTrace);
        await controller.close();
        return;
      }

      // The provider may have been disposed during the awaits above (e.g.
      // connectivity flipped or the last listener went away). Registering
      // onDispose on a dead ref throws, so tear the subscription down inline.
      if (!ref.mounted) {
        await unsubscribe();
        await controller.close();
        return;
      }

      ref.onDispose(() async {
        await unsubscribe?.call();
        await controller.close();
      });

      yield* controller.stream;
    });
