import 'package:zugvogel_ui/src/injection/strings.dart';

/// Reusable, localized form-field validators.
///
/// Each factory takes the [ZugvogelStrings] so messages stay translated, and
/// returns a `String? Function(String?)` matching `FormField.validator`.
abstract final class Validators {
  /// Fails when the trimmed value is empty.
  static String? Function(String?) required(ZugvogelStrings strings) {
    return (value) =>
        (value == null || value.trim().isEmpty) ? strings.fieldRequired : null;
  }

  /// Fails when the value is not a syntactically valid http(s) URL. Empty
  /// passes — compose with [required] when the field is mandatory.
  static String? Function(String?) url(ZugvogelStrings strings) {
    return (value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return null;
      final uri = Uri.tryParse(v);
      final ok =
          uri != null &&
          uri.hasScheme &&
          (uri.isScheme('http') || uri.isScheme('https')) &&
          uri.host.isNotEmpty;
      return ok ? null : strings.fieldInvalidUrl;
    };
  }

  /// Fails when the value is not a plausible email address. Empty passes.
  static String? Function(String?) email(ZugvogelStrings strings) {
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return (value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return null;
      return re.hasMatch(v) ? null : strings.fieldInvalidEmail;
    };
  }

  /// Fails when the value is shorter than [min] characters. Empty passes —
  /// compose with [required] when the field is mandatory. The value is not
  /// trimmed (passwords may legitimately start or end with whitespace).
  static String? Function(String?) minLength(ZugvogelStrings strings, int min) {
    return (value) {
      final v = value ?? '';
      if (v.isEmpty) return null;
      return v.length >= min ? null : strings.fieldMinLength(min);
    };
  }

  /// Fails when the value is not an integer of at least [min]. Empty passes —
  /// compose with [required] when the field is mandatory.
  static String? Function(String?) intMin(ZugvogelStrings strings, int min) {
    return (value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return null;
      final n = int.tryParse(v);
      return (n == null || n < min) ? strings.fieldIntMin(min) : null;
    };
  }

  /// Runs [validators] in order, returning the first failure.
  static String? Function(String?) compose(
    List<String? Function(String?)> validators,
  ) {
    return (value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result != null) return result;
      }
      return null;
    };
  }
}
