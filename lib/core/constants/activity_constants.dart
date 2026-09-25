// Values shared by the Create Activity flow and the Activity Details screen.
//
// Keep in sync with:
// - the `activities` table (max_participants has a `> 1` check in the database)
// - the `activity-photos` bucket created in the Supabase dashboard
class ActivityConstants {
  ActivityConstants._();

  // ---------------------------------------------------------------------------
  // Participants
  // ---------------------------------------------------------------------------

  // The host always counts as one participant, so the smallest activity is
  // the host plus one other person. This matches the database check.
  static const int minParticipants = 2;

  // TODO(team): agreed upper limit is still an open decision. This value is a
  // placeholder so the stepper has a bound; it is not a documented requirement.
  static const int maxParticipants = 20;

  // Value the stepper starts on for a new activity.
  static const int defaultParticipants = 4;

  // ---------------------------------------------------------------------------
  // Text limits
  // ---------------------------------------------------------------------------

  // Not documented as requirements; used only to keep cards and the details
  // screen readable and to stop accidental huge pastes.
  static const int titleMaxLength = 60;
  static const int descriptionMaxLength = 500;
  static const int locationNameMaxLength = 80;

  // ---------------------------------------------------------------------------
  // Photo (one optional photo per activity)
  // ---------------------------------------------------------------------------

  // Must match the bucket created in Supabase Storage.
  static const String photoBucket = 'activity-photos';

  // Picker settings, matching the profile avatar flow.
  static const double photoMaxWidth = 1600;
  static const int photoQuality = 85;

  // Storage object path: <host_id>/<activity_id>.<ext>
  //
  // The folder is the host's user id, which is what the storage policies
  // check, and the file name is the activity id, so deleting an activity can
  // find its photo without storing the path separately.
  static String photoPath({
    required String hostId,
    required String activityId,
    String extension = 'jpg',
  }) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    return '$hostId/$activityId.${ext.isEmpty ? 'jpg' : ext}';
  }
}