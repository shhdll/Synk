import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/auth_deep_link_handler.dart';
import 'models/auth_model.dart';
import 'views/home/main_shell.dart';
import 'views/new_password_view.dart';
import 'views/welcome_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Lets the auth listener navigate without a screen's BuildContext.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  final AuthModel _authModel = AuthModel();
  StreamSubscription<AuthState>? _authSubscription;
  late final AuthDeepLinkHandler _deepLinkHandler;

  // True while the New Password screen is open, so a link tapped twice
  // does not open it twice.
  bool _recoveryScreenOpen = false;

  @override
  void initState() {
    super.initState();

    // ---- Password recovery deep link -------------------------------------
    // After the user opens the reset email link, supabase_flutter exchanges
    // it for a recovery session and emits passwordRecovery. If the link is
    // expired or already used, the exchange fails and the error is
    // delivered on the same stream.
    _authSubscription = _authModel.authStateChanges.listen(
      (state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _openNewPasswordScreen(linkExpired: false);
        }
      },
      onError: (Object error) {
        if (_isRecoveryLinkError(error)) {
          _openNewPasswordScreen(linkExpired: true);
        }
      },
    );

    // ---- synk.cc email links ---------------------------------------------
    // The landing pages forward io.supabase.synk://...?token=<hash>&type=...
    // A successful verify emits signedIn (picked up by the home
    // StreamBuilder and EmailVerificationScreen) or passwordRecovery
    // (picked up by the listener above).
    _deepLinkHandler = AuthDeepLinkHandler(onResult: _onAuthLinkResult)
      ..start();
  }

  void _onAuthLinkResult(OtpType type, AuthLinkOutcome outcome) {
    if (type == OtpType.recovery) {
      if (outcome == AuthLinkOutcome.failed) {
        _openNewPasswordScreen(linkExpired: true);
      }
      return;
    }

    final message = switch ((type, outcome)) {
      (_, AuthLinkOutcome.failed) =>
        'This link has expired or was already used. Please request a new one.',
      (OtpType.emailChange, AuthLinkOutcome.emailChangePartial) =>
        'Confirmed. Now open the link sent to your other email address.',
      (OtpType.emailChange, AuthLinkOutcome.verified) =>
        'Your email address was updated.',
      _ => null,
    };
    if (message == null) return;

    void show() {
      final messenger = _messengerKey.currentState;
      if (messenger == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => show());
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }

    show();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _deepLinkHandler.dispose();
    super.dispose();
  }

  bool _isRecoveryLinkError(Object error) {
    if (error is! AuthException) return false;
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    return code == 'otp_expired' ||
        code == 'access_denied' ||
        message.contains('expired') ||
        message.contains('invalid');
  }

  void _openNewPasswordScreen({required bool linkExpired}) {
    if (_recoveryScreenOpen) return;
    _recoveryScreenOpen = true;

    // On a cold start the event can arrive before the first frame, when the
    // navigator does not exist yet; wait for the frame in that case.
    void push() {
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => push());
        return;
      }
      navigator
          .push(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 250),
              pageBuilder: (_, _, _) =>
                  NewPasswordView(linkExpired: linkExpired),
              transitionsBuilder: (_, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          )
          .whenComplete(() => _recoveryScreenOpen = false);
    }

    push();
  }
  // ---- end password recovery ----------------------------------------------

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Synk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF9F5C)),
        fontFamily: GoogleFonts.inter().fontFamily,
      ),
      home: StreamBuilder<AuthState>(
        stream: _authModel.authStateChanges,
        builder: (context, snapshot) {
          final session = Supabase.instance.client.auth.currentSession;
          final user = session?.user;
          final isConfirmed =
              session != null &&
              user != null &&
              user.emailConfirmedAt != null &&
              user.emailConfirmedAt!.isNotEmpty;

          return isConfirmed ? const MainShell() : const WelcomeView();
        },
      ),
    );
  }
}
