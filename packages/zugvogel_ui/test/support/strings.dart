import 'package:zugvogel_ui/zugvogel_ui.dart';

/// A [ZugvogelStrings] whose every value names its own member.
///
/// Tests can then assert that a widget shows the right *slot* without
/// asserting on any product's wording — which is exactly the property the
/// boundary is about.
class TestStrings implements ZugvogelStrings {
  const TestStrings({this.localeName = 'en'});

  @override
  final String localeName;

  @override
  String get actionCancel => 'actionCancel';
  @override
  String get actionRetry => 'actionRetry';
  @override
  String get actionSave => 'actionSave';
  @override
  String get discardChangesTitle => 'discardChangesTitle';
  @override
  String get discardChangesMessage => 'discardChangesMessage';
  @override
  String get discardConfirm => 'discardConfirm';
  @override
  String get discardKeepEditing => 'discardKeepEditing';
  @override
  String get loadingLabel => 'loadingLabel';
  @override
  String get emptyGeneric => 'emptyGeneric';
  @override
  String get offlineNotice => 'offlineNotice';
  @override
  String get errorGenericTitle => 'errorGenericTitle';
  @override
  String get errorOffline => 'errorOffline';
  @override
  String get errorUnauthorized => 'errorUnauthorized';
  @override
  String get errorNotFound => 'errorNotFound';
  @override
  String get errorValidation => 'errorValidation';
  @override
  String get errorUnknownOutcome => 'errorUnknownOutcome';
  @override
  String get errorLoadFailed => 'errorLoadFailed';
  @override
  String get fieldRequired => 'fieldRequired';
  @override
  String get fieldInvalidEmail => 'fieldInvalidEmail';
  @override
  String get fieldInvalidUrl => 'fieldInvalidUrl';
  @override
  String fieldMinLength(int min) => 'fieldMinLength($min)';
  @override
  String fieldIntMin(int min) => 'fieldIntMin($min)';
  @override
  String get photoAddAction => 'photoAddAction';
  @override
  String get photoCaptureAction => 'photoCaptureAction';
  @override
  String get imageCropTitle => 'imageCropTitle';
  @override
  String get imageCropFailed => 'imageCropFailed';
  @override
  String get imagePrevious => 'imagePrevious';
  @override
  String get imageNext => 'imageNext';
  @override
  String get imageShareAction => 'imageShareAction';
  @override
  String get imageShareFailed => 'imageShareFailed';
}
