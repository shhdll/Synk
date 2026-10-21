import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controllers/language_controller.dart';
import 'l10n/l10n.dart';
import 'models/auth_deep_link_handler.dart';
import 'models/auth_model.dart';
import 'models/activity_model.dart';
import 'services/push_notification_service.dart';
import 'views/home/activity_notification_route.dart';
import 'views/home/activity_join_requests_view.dart';
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

  await LanguageController.instance.load();

  await PushNotificationService.instance.initialize();

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
    PushNotificationService.instance.setActivityTapHandler(
      _openNotificationActivity,
    );
    PushNotificationService.instance.setJoinRequestsTapHandler(
      _openJoinRequests,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainPendingActivityNotification();
      _drainPendingJoinRequestsNotification();
    });

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

    LanguageController.instance.addListener(_onLanguageChanged);
  }

  // Rebuilds every screen, including text built outside a widget (such as
  // labels from models), so nothing is left in the old language.
  void _onLanguageChanged() {
    setState(() {});
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  String? _pendingNotificationActivityId;
  bool _pendingJoinRequestsNotification = false;

  void _openNotificationActivity(String activityId) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      _pendingNotificationActivityId = activityId;
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ActivityNotificationRoute(activityId: activityId),
      ),
    );
  }

  void _drainPendingActivityNotification() {
    final activityId = _pendingNotificationActivityId;
    if (activityId == null || _navigatorKey.currentState == null) return;
    _pendingNotificationActivityId = null;
    _openNotificationActivity(activityId);
  }

  void _openJoinRequests() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      _pendingJoinRequestsNotification = true;
      return;
    }

    final activityStore = ActivityStore()
      ..currentUserId = Supabase.instance.client.auth.currentUser?.id;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ActivityJoinRequestsView(activityStore: activityStore),
      ),
    );
  }

  void _drainPendingJoinRequestsNotification() {
    if (!_pendingJoinRequestsNotification ||
        _navigatorKey.currentState == null) {
      return;
    }
    _pendingJoinRequestsNotification = false;
    _openJoinRequests();
  }

  void _onAuthLinkResult(OtpType type, AuthLinkOutcome outcome) {
    if (type == OtpType.recovery) {
      if (outcome == AuthLinkOutcome.failed) {
        _openNewPasswordScreen(linkExpired: true);
      }
      return;
    }

    final message = switch ((type, outcome)) {
      (_, AuthLinkOutcome.failed) => appL10n.thisLinkHasExpiredOrWas,
      (OtpType.emailChange, AuthLinkOutcome.emailChangePartial) =>
        appL10n.confirmedNowOpenTheLinkSent,
      (OtpType.emailChange, AuthLinkOutcome.verified) =>
        appL10n.yourEmailAddressWasUpdated,
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
    LanguageController.instance.removeListener(_onLanguageChanged);
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
      locale: LanguageController.instance.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF9F5C)),
        fontFamily: GoogleFonts.inter().fontFamily,
        // Inter has no Arabic letters.
        fontFamilyFallback: [GoogleFonts.ibmPlexSansArabic().fontFamily!],
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
