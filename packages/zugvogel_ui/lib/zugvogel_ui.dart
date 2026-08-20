/// Shared Flutter widgets for the Zugvogel apps.
///
/// The three injection boundaries apply hardest here (see CLAUDE.md, and the
/// sweep in `test/injection_boundaries_test.dart` that enforces them):
///
/// 1. No widget imports an l10n class. Text arrives through an injected
///    `ZugvogelStrings`; a widget that knows the word "Abbrechen" is a bug.
/// 2. No widget names a colour. Widgets read `Theme.of(context).colorScheme`
///    plus `ZugvogelSemantics` for good/warning/critical and the categorical
///    chart palette.
/// 3. No widget reads configuration. Whatever it needs is passed in.
///
/// Together these are what keep a wide shared UI package from welding two
/// product designs together.
library;

export 'src/errors.dart';
export 'src/injection/semantics.dart';
export 'src/injection/strings.dart';
export 'src/layout/window_size.dart';
export 'src/number_format.dart';
export 'src/quick_action.dart';
export 'src/sheets/app_sheet.dart';
export 'src/sheets/destructive_dialog.dart';
export 'src/sheets/discard_guard.dart';
export 'src/sheets/form_sheet.dart';
export 'src/theme/spacing.dart';
export 'src/validators.dart';
export 'src/widgets/app_text_field.dart';
export 'src/widgets/async_value_view.dart';
export 'src/widgets/attachment_kind.dart';
export 'src/widgets/cached_file_image.dart';
export 'src/widgets/date_field.dart';
export 'src/widgets/destructive_action_button.dart';
export 'src/widgets/detail_header.dart';
export 'src/widgets/editable_photo_strip.dart';
export 'src/widgets/empty_view.dart';
export 'src/widgets/error_view.dart';
export 'src/widgets/icon_chip.dart';
export 'src/widgets/image_cropper.dart';
export 'src/widgets/image_viewer.dart';
export 'src/widgets/loading_view.dart';
export 'src/widgets/map_attribution.dart';
export 'src/widgets/map_tile_layer.dart';
export 'src/widgets/map_wheel_zoom.dart';
export 'src/widgets/menu_action.dart';
export 'src/widgets/offline_notice.dart';
export 'src/widgets/paged_list_tail.dart';
export 'src/widgets/primary_button.dart';
export 'src/widgets/staged_photos.dart';
export 'src/widgets/tag_chip.dart';
