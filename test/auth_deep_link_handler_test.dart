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

  test('reads the token hash from token or token_hash', () {
    String? hashOf(String link) =>
        AuthDeepLinkHandler.tokenHashFor(Uri.parse(link));

    expect(hashOf('io.supabase.synk://login-callback?token=abc'), 'abc');
    expect(hashOf('io.supabase.synk://login-callback?token_hash=abc'), 'abc');
    expect(hashOf('io.supabase.synk://login-callback?token='), isNull);
    expect(hashOf('io.supabase.synk://login-callback'), isNull);
  });

  test('describes links without leaking tokens', () {
    final text = AuthDeepLinkHandler.describe(
      Uri.parse(
        'io.supabase.synk://login-callback?refresh_token=secret12345&type=signup',
      ),
    );
    expect(text, contains('type: signup'));
    expect(text, contains('secret…'));
    expect(text, isNot(contains('secret12345')));
  });
}
