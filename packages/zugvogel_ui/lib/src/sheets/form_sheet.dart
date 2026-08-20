import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zugvogel_core/zugvogel_core.dart';
import 'package:zugvogel_data/zugvogel_data.dart';
import 'package:zugvogel_ui/src/errors.dart';
import 'package:zugvogel_ui/src/injection/strings.dart';
import 'package:zugvogel_ui/src/theme/spacing.dart';
import 'package:zugvogel_ui/src/widgets/primary_button.dart';

/// Mixin for a create/edit sheet's [ConsumerState]: owns the busy/error pair
/// and [formKey], plus [runSave] — the `_save()` try/catch tail every sheet
/// otherwise repeats. Pair with `DiscardGuard` for the unsaved-changes guard
/// and [SheetScaffold] for the surrounding layout.
///
/// The org/permission guard every app puts in front of a write does **not**
/// live here: resolving "the signed-in user and their organisation" needs the
/// app's own user model. Write it in the app and call it from the [runSave]
/// body.
mixin FormSheetState<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Owned so sheets do not each declare `final _formKey = GlobalKey<...>()`.
  final formKey = GlobalKey<FormState>();

  bool _busy = false;
  String? _error;

  bool get isBusy => _busy;
  String? get saveError => _error;

  /// Shows [message] in the same slot [runSave] uses, for a validation check
  /// that must run before the try/catch (e.g. a cross-field rule `Form`
  /// validators cannot express).
  void setSaveError(String message) => setState(() => _error = message);

  /// Runs [action] under the shared busy/error lifecycle. On success [isBusy]
  /// is left true — the caller pops the sheet next. A [RepositoryException] is
  /// rendered through [errorMessage]; any other error is reported via
  /// [reportCaughtError] and shown as a generic message. Either failure clears
  /// [isBusy]. Returns whether [action] completed without error.
  ///
  /// Pass [clearBusyOnSuccess] where the surface STAYS after a successful save
  /// — a settings screen that reports with a snackbar rather than closing.
  /// Leaving the button spinning forever is only correct when the thing it
  /// sits on is about to go away.
  Future<bool> runSave(
    Future<void> Function() action, {
    bool clearBusyOnSuccess = false,
  }) async {
    final strings = context.zv;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (clearBusyOnSuccess && mounted) setState(() => _busy = false);
      return true;
    } on RepositoryException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorMessage(strings, e);
        });
      }
      return false;
    } on Object catch (error, stackTrace) {
      reportCaughtError(error, stackTrace);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = strings.errorGenericTitle;
        });
      }
      return false;
    }
  }
}

/// The padding/scroll/Form/title/error-slot/save-button shell every create/edit
/// sheet otherwise hand-rolls. Wrap the returned widget in
/// `guardUnsavedChanges` (from the `DiscardGuard` mixin); [children] are the
/// sheet's own fields.
///
/// [formKey], [isBusy] and [error] normally come straight from a
/// [FormSheetState] mixed into the same state, and [onSave] from its `_save()`.
/// [trailing] renders below the save button.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    required this.title,
    required this.formKey,
    required this.onFormChanged,
    required this.children,
    required this.isBusy,
    required this.error,
    required this.onSave,
    this.saveLabel,
    this.saveIcon = Icons.check,
    this.trailing = const [],
    super.key,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final VoidCallback onFormChanged;
  final List<Widget> children;
  final bool isBusy;
  final String? error;
  final VoidCallback onSave;

  /// Defaults to the injected generic "save" label.
  final String? saveLabel;

  /// Defaults to the check every save button carries. Override where the
  /// action is not a save in the usual sense — an invite SENDS something, and
  /// its button should say so.
  final IconData saveIcon;

  /// Extra widgets rendered after the save button.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final strings = context.zv;
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        ZugvogelSpacing.lg,
        0,
        ZugvogelSpacing.lg,
        ZugvogelSpacing.lg + viewInsets,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          onChanged: onFormChanged,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: ZugvogelSpacing.md),
              ...children,
              if (error != null) ...[
                const SizedBox(height: ZugvogelSpacing.sm),
                Text(
                  error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: ZugvogelSpacing.lg),
              PrimaryButton(
                label: saveLabel ?? strings.actionSave,
                icon: saveIcon,
                isLoading: isBusy,
                onPressed: onSave,
              ),
              ...trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Trims a controller's text, returning null for an empty result — the `_trim`
/// helper every sheet with optional text fields otherwise repeats.
String? trimToNull(TextEditingController controller) {
  final value = controller.text.trim();
  return value.isEmpty ? null : value;
}
