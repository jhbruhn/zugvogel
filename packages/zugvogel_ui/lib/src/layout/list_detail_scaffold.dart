import 'package:flutter/material.dart';
import 'package:zugvogel_ui/src/layout/window_size.dart';
import 'package:zugvogel_ui/src/theme/spacing.dart';
import 'package:zugvogel_ui/src/widgets/empty_view.dart';

/// Pure two-pane layout: a fixed-width [list] on the left, a divider, and the
/// [detail] filling the rest.
///
/// Knows nothing about routing — the caller decides what each pane is and when
/// to use it. The adaptive *shell* that picks between one and two panes stays
/// in the app: it has to read the current route to know whether a detail is
/// open, and route names are the app's.
class ListDetailScaffold extends StatelessWidget {
  const ListDetailScaffold({
    required this.list,
    required this.detail,
    super.key,
  });

  /// Left pane — the list. Constrained to [kListPaneWidth].
  final Widget list;

  /// Right pane — the selected item's detail, or a [DetailPanePlaceholder].
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: kListPaneWidth, child: list),
        const VerticalDivider(width: 1),
        Expanded(child: detail),
      ],
    );
  }
}

/// What the detail pane shows before anything is selected.
class DetailPanePlaceholder extends StatelessWidget {
  const DetailPanePlaceholder({required this.message, this.icon, super.key});

  /// Prompt, e.g. "Select a record to view its details". Injected, like every
  /// other string a shared widget shows.
  final String message;

  /// Optional leading icon; defaults to a neutral selection cue.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // A Material of its own so the pane has a proper background (and text/icon
    // theming) even when it renders outside a Scaffold — e.g. as the right pane
    // of a bare Row.
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(ZugvogelSpacing.lg),
        child: EmptyView(
          icon: icon ?? Icons.touch_app_outlined,
          message: message,
        ),
      ),
    );
  }
}
