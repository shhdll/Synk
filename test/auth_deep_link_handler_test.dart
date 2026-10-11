import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:synk/models/auth_deep_link_handler.dart';

void main() {
  OtpType? typeOf(String link) =>
      AuthDeepLinkHandler.otpTypeFor(Uri.parse(link));

  test('maps landing page links to OTP types', () {
    expect(
      typeOf('io.supabase.synk://login-callback?token=abc&type=signup'),
      OtpType.signup,
    );
    expect(
      typeOf('io.supabase.synk://login-callback?token=abc&type=magiclink'),
      OtpType.magiclink,
    );
    expect(
      typeOf('io.supabase.synk://login-callback?token=abc&type=email_change'),
      OtpType.emailChange,
    );
    expect(
      typeOf('io.supabase.synk://reset-password?token=abc'),
      OtpType.recovery,
    );
  });

  test('ignores unknown or missing types', () {
    expect(typeOf('io.supabase.synk://login-callback?token=abc'), isNull);
    expect(
      typeOf('io.supabase.synk://login-callback?token=abc&type=bogus'),
      isNull,
    );
  });
}
