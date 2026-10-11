import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/auth_constants.dart';

// What happened when a token-hash email link was opened.
enum AuthLinkOutcome {
  // Session created; onAuthStateChange has already emitted signedIn or
  // passwordRecovery.
  verified,

  // Secure email change: one of the two addresses is confirmed, the other
  // still has to be confirmed before the change takes effect.
  emailChangePartial,

  // The link was expired, already used, or otherwise rejected.
  failed,
}

// Handles io.supabase.synk:// links sent by the synk.cc landing pages:
// - ?refresh_token=...&type=...: the page already confirmed the link
//   (sign-up, magic link); the app signs in with that session.
// - ?token=<hash>&type=...: the app confirms the link itself with verifyOTP
//   (password reset, or when the page could not reach Supabase).
//
// supabase_flutter only processes links that carry `code` or `access_token`,
// so neither kind is picked up by it.
class AuthDeepLinkHandler {
  AuthDeepLinkHandler({required this.onResult, AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final void Function(OtpType type, AuthLinkOutcome outcome) onResult;
  final AppLinks _appLinks;

  StreamSubscription<Uri>? _subscription;

  // The initial link is also replayed on the stream on some platforms;
  // remember handled tokens so each one is verified only once.
  final Set<String> _handledTokens = {};

  Future<void> start() async {
    _subscription = _appLinks.uriLinkStream.listen(_handle);
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _handle(initial);
    } catch (e) {
      debugPrint('AuthDeepLinkHandler: initial link error: $e');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }

  // Maps the landing page `type` param to an OtpType. Reset-password links
  // carry no type, so the host decides.
  static OtpType? otpTypeFor(Uri uri) {
    if (uri.host == AuthConstants.resetPasswordHost) return OtpType.recovery;

    return switch (uri.queryParameters['type']) {
      'signup' => OtpType.signup,
      'magiclink' => OtpType.magiclink,
      'email_change' => OtpType.emailChange,
      'recovery' => OtpType.recovery,
      'invite' => OtpType.invite,
      'email' => OtpType.email,
      _ => null,
    };
  }

  Future<void> _handle(Uri uri) async {
    if (uri.scheme != AuthConstants.appScheme) return;

    // The synk.cc page already confirmed the link and passes on the
    // session it received, so the app signs straight in.
    final refreshToken = uri.queryParameters['refresh_token'];
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _signInWithRefreshToken(uri, refreshToken);
      return;
    }

    final tokenHash = uri.queryParameters['token'];
    if (tokenHash == null || tokenHash.isEmpty) return;
    if (!_handledTokens.add(tokenHash)) return;

    final type = otpTypeFor(uri);
    if (type == null) return;

    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        tokenHash: tokenHash,
        type: type,
      );
      onResult(
        type,
        response.session == null && type == OtpType.emailChange
            ? AuthLinkOutcome.emailChangePartial
            : AuthLinkOutcome.verified,
      );
    } catch (e) {
      debugPrint('AuthDeepLinkHandler: verify failed: $e');
      onResult(type, AuthLinkOutcome.failed);
    }
  }

  Future<void> _signInWithRefreshToken(Uri uri, String refreshToken) async {
    if (!_handledTokens.add(refreshToken)) return;
    final type = otpTypeFor(uri) ?? OtpType.signup;

    try {
      // Emits tokenRefreshed, which EmailVerificationScreen and the home
      // StreamBuilder both act on.
      await Supabase.instance.client.auth.setSession(refreshToken);
      onResult(type, AuthLinkOutcome.verified);
    } catch (e) {
      debugPrint('AuthDeepLinkHandler: setSession failed: $e');
      onResult(type, AuthLinkOutcome.failed);
    }
  }
}
