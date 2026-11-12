import '../l10n/l10n.dart';
import '../models/activity_save_model.dart';

// The message for a save that didn't go through. Only these fixed,
// translated messages are ever shown; the server never sends text, scores
// or database errors.
String activitySaveMessage(ActivitySaveResult result, {required bool editing}) {
  final couldntSave = editing
      ? appL10n.weCouldntSaveYourChanges
      : appL10n.weCouldntCreateYourActivityPlease;
  return switch (result.code) {
    ActivitySaveCode.saved => '',
    ActivitySaveCode.alreadyExists => appL10n.activityAlreadySaved,
    ActivitySaveCode.rejected =>
      result.fields.length == 1 && result.fields.single == 'photo'
          ? appL10n.activityPhotoRejected
          : appL10n.activityGuidelinesRejected,
    ActivitySaveCode.invalid =>
      result.fields.contains('time')
          ? appL10n.activityEndBeforeStart
          : result.fields.contains('capacity')
          ? appL10n.capacityBelowParticipants
          : couldntSave,
    ActivitySaveCode.photoInvalid || ActivitySaveCode.payloadTooLarge =>
      result.reason == 'too_large' ||
              result.code == ActivitySaveCode.payloadTooLarge
          ? appL10n.activityPhotoTooLarge
          : appL10n.activityPhotoCantBeUsed,
    ActivitySaveCode.notFound => appL10n.activityNoLongerExists,
    ActivitySaveCode.notHost => appL10n.notHostAnymore,
    ActivitySaveCode.suspended => appL10n.accountSuspendedCantSave,
    ActivitySaveCode.conflict => appL10n.activityChangedElsewhere,
    ActivitySaveCode.scheduleConflict =>
      appL10n.youAlreadyHaveAnActivityAtThisTime,
    ActivitySaveCode.capacityBelowParticipants =>
      appL10n.capacityBelowParticipants,
    ActivitySaveCode.scheduleTooFar => appL10n.chooseADateWithinTheNext,
    ActivitySaveCode.invalidTimeRange => appL10n.activityEndBeforeStart,
    ActivitySaveCode.rateLimited => appL10n.activitySaveTooOften,
    ActivitySaveCode.busy => appL10n.activityStillSaving,
    ActivitySaveCode.moderationUnavailable => appL10n.activityCheckUnavailable,
    ActivitySaveCode.connectionLost => appL10n.activityCouldntConfirm,
    ActivitySaveCode.unauthorized => appL10n.signInAgainToSave,
    ActivitySaveCode.requestMismatch ||
    ActivitySaveCode.tooManyAttempts ||
    ActivitySaveCode.invalidRequest => appL10n.somethingWentWrongPleaseTryAgain,
    ActivitySaveCode.storageFailed ||
    ActivitySaveCode.saveFailed => couldntSave,
  };
}
