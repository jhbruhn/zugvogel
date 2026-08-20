import 'package:flutter/widgets.dart';

/// Material 3 window-size classes — the single source of truth for mapping the
/// current width to a layout decision. Everything adaptive derives from here
/// instead of sprinkling raw `MediaQuery` width checks through the widget tree.
///
/// Breakpoints follow the M3 spec: compact `< 600`, medium `600–839`, expanded
/// `>= 840` (logical pixels).
enum WindowSizeClass {
  /// Phones in portrait — single pane, bottom navigation.
  compact,

  /// Large phones / small tablets — single pane, navigation rail.
  medium,

  /// Tablets / desktop / web — room for two panes, extended rail.
  expanded;

  /// Whether this class is [expanded] (i.e. wide enough for two panes).
  bool get isExpanded => this == WindowSizeClass.expanded;
}

/// Width (logical px) at/above which the layout is [WindowSizeClass.medium].
const double kMediumMin = 600;

/// Width (logical px) at/above which the layout is [WindowSizeClass.expanded]
/// and the canonical list-detail surfaces show both panes.
const double kExpandedMin = 840;

/// Fixed width of the list pane in a two-pane (list-detail) layout.
const double kListPaneWidth = 360;

/// Maximum width for flat, scrolling page content (settings lists, profiles,
/// statistics, admin sections). Beyond this, content is centred with margins so
/// rows and bars do not stretch to an unreadable length on wide windows. See
/// `ContentBounds`.
const double kContentMaxWidth = 840;

/// Maximum width for a modal sheet's content. On wide windows the sheet floats
/// centred at this width instead of stretching edge-to-edge; below it the sheet
/// fills the screen. See `showAppSheet`.
const double kSheetMaxWidth = 640;

/// Width cap for a page that has earned two columns. Wider than
/// [kContentMaxWidth] because two columns of chart or of cards need the room;
/// without a cap a 4K window would stretch a breakdown row across half a metre.
const double kWideContentMaxWidth = 1280;

// Breakpoints ABOVE these are each app's own, because they are tuned to
// specific content: which width a particular dashboard needs before its KPI
// tiles stop being readable is a fact about that dashboard, not about
// Material's size classes. Derive them in the app, from the widths here.

/// Maps a raw width to its [WindowSizeClass].
WindowSizeClass windowSizeClassFor(double width) {
  if (width >= kExpandedMin) return WindowSizeClass.expanded;
  if (width >= kMediumMin) return WindowSizeClass.medium;
  return WindowSizeClass.compact;
}

/// Window-size helpers on [BuildContext]. Reads `MediaQuery.sizeOf`, so callers
/// rebuild when the window is resized.
extension WindowSizeContext on BuildContext {
  /// The current [WindowSizeClass] for this context's width.
  WindowSizeClass get windowSizeClass =>
      windowSizeClassFor(MediaQuery.sizeOf(this).width);

  /// Whether the current width is [WindowSizeClass.expanded] — i.e. wide enough
  /// to show a list and a detail side-by-side.
  bool get isExpanded => windowSizeClass.isExpanded;
}
