import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/activity_save_messages.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/activity_model.dart';
import '../../models/activity_save_model.dart';
import '../../models/pending_activity_save_store.dart';
import '../../utils/custom_widgets/synk_dialog.dart';
import '../../utils/custom_widgets/synk_feedback.dart';

bool _offering = false;

// Offers to finish a save that never got a final answer, e.g. the app was
// closed or the connection dropped while saving. It sends exactly the same
// request again, so the server either returns what already happened or
// finishes the save; it can't create a second activity. Shown when the app
// opens and when the create or edit form opens.
//
// Returns the saved activity, if this finished one.
Future<Activity?> offerPendingActivitySave(
  BuildContext context, {
  ActivityStore? store,
  ActivitySaveService? service,
  PendingActivitySaveStore pending = const PendingActivitySaveStore(),
}) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null || _offering) return null;
  final request = await pending.load(userId);
  if (request == null || !context.mounted) return null;

  _offering = true;
  try {
    final choice = await SynkDialog(
      icon: Icons.cloud_upload_outlined,
      iconColor: SynkColors.orangeDark,
      iconBackground: const Color(0x24FF7A36),
      title: context.l10n.finishSavingActivityTitle,
      message: context.l10n.finishSavingActivityMessage,
      primaryLabel: context.l10n.finishSaving,
      secondaryLabel: context.l10n.discard,
      showPrimaryArrow: false,
    ).show(context);
    // Closed without choosing: ask again next time.
    if (choice == null || !context.mounted) return null;

    if (choice == SynkDialogAction.secondary) {
      await pending.clear(userId, requestId: request.requestId);
      return null;
    }

    final result = await (service ?? ActivitySaveService()).save(request);
    if (result.isFinal) {
      await pending.clear(userId, requestId: request.requestId);
    }
    if (!context.mounted) return null;

    final editing = request.operation == ActivitySaveOperation.update;
    final saved = result.activity;
    if ((result.isSaved || result.code == ActivitySaveCode.alreadyExists) &&
        saved != null) {
      store?.upsert(saved);
      SynkFeedback.showToast(
        context,
        title: editing
            ? context.l10n.changesSaved
            : context.l10n.activityCreated,
      );
      return saved;
    }
    // The server decided against it (e.g. rejected or changed elsewhere):
    // nothing was saved, and the form it came from is gone.
    SynkFeedback.showToast(
      context,
      title: result.isFinal
          ? context.l10n.activitySaveDiscarded
          : activitySaveMessage(result, editing: editing),
      message: result.isFinal
          ? activitySaveMessage(result, editing: editing)
          : null,
      success: false,
    );
    return null;
  } finally {
    _offering = false;
  }
}
