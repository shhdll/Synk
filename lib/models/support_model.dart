import 'package:supabase_flutter/supabase_flutter.dart';

// Sends a message to the Synk team (supabase/functions/submit-support).
enum SupportCategory {
  problem('problem'),
  feedback('feedback'),
  other('other');

  const SupportCategory(this.value);

  final String value;
}

enum SupportResult { sent, rateLimited, failed }

class SupportModel {
  SupportModel({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  static const int maxLength = 2000;

  final SupabaseClient _supabase;

  String? get userEmail => _supabase.auth.currentUser?.email;

  Future<SupportResult> send({
    required SupportCategory category,
    required String message,
    String? appVersion,
  }) async {
    try {
      await _supabase.functions.invoke(
        'submit-support',
        body: {
          'category': category.value,
          'message': message.trim(),
          'app_version': ?appVersion,
        },
      );
      return SupportResult.sent;
    } on FunctionException catch (error) {
      return error.status == 429
          ? SupportResult.rateLimited
          : SupportResult.failed;
    } catch (_) {
      return SupportResult.failed;
    }
  }
}
