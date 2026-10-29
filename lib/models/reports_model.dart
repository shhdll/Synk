import 'package:supabase_flutter/supabase_flutter.dart';

// Reports about other users, reviewed by the Synk team. Reports go through
// report_user() (supabase/migrations/20261028210000_user_reports.sql), and
// users can't read them back.

// The values match the reason check in user_reports.
enum ReportReason {
  harassment('harassment'),
  spam('spam'),
  fakeProfile('fake_profile'),
  inappropriateContent('inappropriate_content'),
  other('other');

  const ReportReason(this.value);

  final String value;
}

class ReportsModel {
  SupabaseClient get _supabase => Supabase.instance.client;

  // Returns the function's result, e.g. 'reported' or 'already_reported'.
  Future<String> reportUser({
    required String userId,
    required ReportReason reason,
    String? details,
  }) async {
    final response = await _supabase.rpc(
      'report_user',
      params: {
        'target_user_id': userId,
        'report_reason': reason.value,
        'report_details': details,
      },
    );
    if (response is Map && response['result'] is String) {
      return response['result'] as String;
    }
    return '';
  }
}
