import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/auth_constants.dart';

enum AuthLinkOutcome { verified, emailChangePartial, failed }

class AuthDeepLinkHandler {
  AuthDeepLinkHandler({
    required this.onResult,
    this.onActivityLink,
    AppLinks? appLinks,
  }) : _appLinks = appLinks ?? AppLinks();

  final void Function(OtpType type, AuthLinkOutcome outcome) onResult;

  // A shared activity link, io.supabase.synk://activity?id=...
  final void Function(String activityId, String? code)? onActivityLink;
  final AppLinks _appLinks;

  StreamSubscription<Uri>? _subscription;
  final Set<String> _handledTokens = {};

  Future<void> start() async {
    _log('listening for ${AuthConstants.appScheme}:// links');
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      _log('stream link: ${describe(uri)}');
      _handle(uri);
    }, onError: (Object e) => _log('link stream error: $e'));
    try {
      final initial = await _appLinks.getInitialLink();
      _log('initial link: ${initial == null ? 'none' : describe(initial)}');
      if (initial != null) await _handle(initial);
    } catch (e) {
      _log('initial link error: $e');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }

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

  // The token hash in a link; `token_hash` is accepted as well as `token`.
  static String? tokenHashFor(Uri uri) {
    for (final key in const ['token', 'token_hash']) {
      final value = uri.queryParameters[key];
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  // The link without its secrets, safe to log.
  static String describe(Uri uri) {
    final params = uri.queryParameters.map(
      (key, value) => MapEntry(
        key,
        key == 'type' || value.length <= 6
            ? value
            : '${value.substring(0, 6)}…',
      ),
    );
    return '${uri.scheme}://${uri.host}${uri.path} $params';
  }

  Future<void> _handle(Uri uri) async {
    if (uri.scheme != AuthConstants.appScheme) {
      _log('ignored: scheme is not ${AuthConstants.appScheme}');
      return;
    }

    if (uri.host == 'activity') {
      final id = uri.queryParameters['id'];
      if (id != null && id.isNotEmpty) {
        onActivityLink?.call(id, uri.queryParameters['code']);
      }
      return;
    }

    // The synk.cc page already confirmed the link and passes on the
    // session it received, so the app signs straight in.
    final refreshToken = uri.queryParameters['refresh_token'];
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _signInWithRefreshToken(uri, refreshToken);
      return;
    }

    final tokenHash = tokenHashFor(uri);
    if (tokenHash == null) {
      // A bare login-callback link (e.g. the page confirmed the email but got
      // no session back) has nothing to sign in with.
      _log('ignored: no refresh_token or token in link');
      return;
    }
    if (!_handledTokens.add(tokenHash)) {
      _log('ignored: token already handled');
      return;
    }

    final type = otpTypeFor(uri);
    if (type == null) {
      _log('ignored: unknown type "${uri.queryParameters['type']}"');
      return;
    }

    try {
      _log('verifyOTP(type: ${type.name})');
      final response = await Supabase.instance.client.auth.verifyOTP(
        tokenHash: tokenHash,
        type: type,
      );
      _log(
        'verifyOTP ok: session=${response.session != null}, '
        'confirmed=${response.user?.emailConfirmedAt != null}',
      );
      onResult(
        type,
        response.session == null && type == OtpType.emailChange
            ? AuthLinkOutcome.emailChangePartial
            : AuthLinkOutcome.verified,
      );
    } catch (e) {
      _log('verifyOTP failed: $e');
      onResult(type, AuthLinkOutcome.failed);
    }
  }

  Future<void> _signInWithRefreshToken(Uri uri, String refreshToken) async {
    if (!_handledTokens.add(refreshToken)) {
      _log('ignored: refresh token already handled');
      return;
    }
    final type = otpTypeFor(uri) ?? OtpType.signup;

    try {
      _log('setSession(type: ${type.name})');
      // Emits tokenRefreshed, which EmailVerificationScreen and the home
      // StreamBuilder both act on.
      final response = await Supabase.instance.client.auth.setSession(
        refreshToken,
      );
      _log(
        'setSession ok: confirmed=${response.user?.emailConfirmedAt != null}',
      );
      onResult(type, AuthLinkOutcome.verified);
    } catch (e) {
      _log('setSession failed: $e');
      onResult(type, AuthLinkOutcome.failed);
    }
  }

  static void _log(String message) =>
      debugPrint('AuthDeepLinkHandler: $message');
}
