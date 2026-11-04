import 'dart:io';

import 'package:image_picker/image_picker.dart';
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
  static const int minLength = 10;
  static const int maxScreenshots = 3;
  static const String screenshotBucket = 'support-screenshots';

  final SupabaseClient _supabase;
  final ImagePicker _picker = ImagePicker();

  String? get userEmail => _supabase.auth.currentUser?.email;

  Future<XFile?> pickScreenshot() => _picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 85,
  );

  // Uploads into the user's own folder and returns the path to send.
  Future<String> uploadScreenshot(XFile file) async {
    final me = _supabase.auth.currentUser?.id ?? 'unknown';
    final extension = file.path.split('.').last.toLowerCase();
    final type = switch (extension) {
      'png' => 'png',
      'heic' => 'heic',
      'webp' => 'webp',
      _ => 'jpeg',
    };
    final path =
        '$me/${DateTime.now().microsecondsSinceEpoch}'
        '.${type == 'jpeg' ? 'jpg' : type}';
    await _supabase.storage
        .from(screenshotBucket)
        .upload(
          path,
          File(file.path),
          fileOptions: FileOptions(contentType: 'image/$type'),
        );
    return path;
  }

  Future<SupportResult> send({
    required SupportCategory category,
    required String message,
    String? appVersion,
    List<String> screenshots = const [],
    String? replyTo,
  }) async {
    try {
      await _supabase.functions.invoke(
        'submit-support',
        body: {
          'category': category.value,
          'message': message.trim(),
          'app_version': ?appVersion,
          if (screenshots.isNotEmpty) 'screenshots': screenshots,
          'reply_to': ?replyTo,
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

  // From the login screen of a suspended account, so there's no session.
  // The reply goes to the account's email.
  Future<bool> sendAppeal({
    required String email,
    required String message,
    String? appVersion,
  }) async {
    try {
      await _supabase.functions.invoke(
        'submit-support',
        body: {
          'action': 'appeal',
          'email': email.trim(),
          'message': message.trim(),
          'app_version': ?appVersion,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
