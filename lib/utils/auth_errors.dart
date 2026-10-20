import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/l10n.dart';

String get kNetworkErrorMessage =>
    appL10n.noInternetConnectionCheckYourConnection;
String get kRateLimitMessage => appL10n.tooManyAttemptsPleaseWaitA;
String get kGenericErrorMessage => appL10n.somethingWentWrongPleaseTryAgain;

// In ilike, _ and % are wildcards, so "a_b" would also match "axb".
String escapeLike(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('%', r'\%')
    .replaceAll('_', r'\_');

bool isNetworkError(Object error) {
  if (error is AuthRetryableFetchException || error is TimeoutException) {
    return true;
  }
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('Network is unreachable');
}

bool isRateLimited(AuthException error) =>
    error.statusCode == '429' ||
    (error.code?.contains('rate_limit') ?? false) ||
    error.message.toLowerCase().contains('rate limit');
