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
import 'services/startup_safe_session_storage.dart';
import 'views/home/activity_notification_route.dart';
import 'views/home/schedule_conflict_resolution_view.dart';
import 'views/home/activity_join_requests_view.dart';
import 'views/home/main_shell.dart';
import 'views/new_password_view.dart';
import 'views/welcome_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StartupGate());
}

final supabase = Supabase.instance.client;

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late final Future<void> _startup = _initialize();
  String _stage = 'Loading app configuration';

  void _setStage(String stage) {
    debugPrint('Synk startup: $stage');
    if (_stage != stage) setState(() => _stage = stage);
  }

  Future<void> _initialize() async {
    try {
      _setStage('Loading app configuration');
      await dotenv.load(fileName: '.env').timeout(const Duration(seconds: 15));

      final url = dotenv.env['SUPABASE_URL'];
      final key = dotenv.env['SUPABASE_ANON_KEY'];
      if (url == null || url.isEmpty || key == null || key.isEmpty) {
        throw StateError('Supabase settings are missing from .env');
      }

      _setStage('Initializing account services');
      await Supabase.initialize(
        url: url,
        publishableKey: key,
        authOptions: FlutterAuthClientOptions(
          // AuthDeepLinkHandler below owns app links for this app.
          detectSessionInUri: false,
          localStorage: StartupSafeSessionStorage(
            persistSessionKey:
                'sb-${Uri.parse(url).host.split('.').first}-auth-token',
          ),
        ),
      ).timeout(const Duration(seconds: 30));

      _setStage('Loading saved preferences');
      await LanguageController.instance.load().timeout(
        const Duration(seconds: 10),
      );
    } catch (error, stackTrace) {
      debugPrint('Synk startup failed during "$_stage": $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const MyApp();
        }

        final failed = snapshot.hasError;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFFF6F1E6),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (failed)
                      const Icon(Icons.error_outline, size: 40)
                    else
                      const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      failed ? 'Synk could not finish starting.' : _stage,
                      textAlign: TextAlign.center,
                    ),
                    if (failed) ...[
                      const SizedBox(height: 8),
                      Text(
                        'It stopped while: $_stage',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

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
    PushNotificationService.instance.setScheduleConflictsTapHandler(
      _openScheduleConflictResolution,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainPendingActivityNotification();
      _drainPendingJoinRequestsNotification();
      _drainPendingScheduleConflictsNotification();
      unawaited(PushNotificationService.instance.initialize());
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
  bool _pendingScheduleConflictsNotification = false;

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

  void _openScheduleConflictResolution() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      _pendingScheduleConflictsNotification = true;
      return;
    }
    showScheduleConflictResolutionDialog(navigator.context);
  }

  void _drainPendingScheduleConflictsNotification() {
    if (!_pendingScheduleConflictsNotification || _navigatorKey.currentState == null) return;
    _pendingScheduleConflictsNotification = false;
    _openScheduleConflictResolution();
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
      // Tapping outside a text field closes the keyboard. iPhone has no
      // other way to close it for multi-line fields.
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
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
