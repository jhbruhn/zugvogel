import 'package:flutter/material.dart';
import 'package:zugvogel_ui/src/errors.dart';
import 'package:zugvogel_ui/src/injection/strings.dart';
import 'package:zugvogel_ui/src/theme/spacing.dart';

/// The extra row below the last item of a keyset-paged list: the next page
/// arriving, or the reason it did not.
///
/// A failure has to be visible and recoverable *here*, at the end of the list.
/// It is the only place it shows, and a list the reader believes they have
/// reached the bottom of is worse than one that says it stopped
/// (federfall-ia9n). Shared by every paged feed, so they all stop the same
/// way.
///
/// It also *asks* for the page it is announcing, if given an [onLoad]: a list
/// builds this row only once it is within reach of the viewport, which is the
/// same moment a scroll listener would decide to fetch — but a list too short
/// to scroll never fires one, and then the tail spins forever below the last
/// row (federfall-etd7). Screens keep their scroll listener on top of this;
/// that one fires a screenful earlier, so pages still arrive before the reader
/// reaches the bottom.
class PagedListTail extends StatefulWidget {
  const PagedListTail({
    required this.onRetry,
    this.error,
    this.onLoad,
    super.key,
  });

  /// Why the last page failed, or null while one is simply in flight.
  final Object? error;

  /// Tries that page again, from the same cursor.
  final VoidCallback onRetry;

  /// Fetches the page this row stands for, if the feed is not already fetching
  /// it. Must be a no-op while a page is in flight — every paged notifier's
  /// `loadMore` is.
  final VoidCallback? onLoad;

  @override
  State<PagedListTail> createState() => _PagedListTailState();
}

class _PagedListTailState extends State<PagedListTail> {
  @override
  Widget build(BuildContext context) {
    final failure = widget.error;
    // Deferred past this frame: loading a page moves the feed's state, and the
    // notifier must not be written to during a build.
    final load = widget.onLoad;
    if (failure == null && load != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
    if (failure == null) {
      return const Padding(
        padding: EdgeInsets.all(ZugvogelSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final zv = context.zv;
    return Padding(
      padding: const EdgeInsets.all(ZugvogelSpacing.lg),
      child: Column(
        spacing: ZugvogelSpacing.sm,
        children: [
          Text(
            loadErrorMessage(zv, failure),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          TextButton.icon(
            onPressed: widget.onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(zv.actionRetry),
          ),
        ],
      ),
    );
  }
}
