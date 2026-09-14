import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/auth_model.dart';
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

  final AuthModel _authModel = AuthModel();
  StreamSubscription<AuthState>? _authSubscription;

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
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
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
      debugShowCheckedModeBanner: false,
      title: 'Synk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF9F5C)),
      ),
      home: const WelcomeView(),
    );
  }
}
